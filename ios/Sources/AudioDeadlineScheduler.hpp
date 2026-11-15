// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <AudioToolbox/AudioWorkInterval.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <mach/thread_policy.h>
#include <pthread.h>
#include <pthread/qos.h>
#include <algorithm>
#include <cstdint>

// Owned and used entirely by the sender thread. No audio device, microphone,
// global service or other process is reconfigured. Unavailable deadlines use
// standard scheduling. Darwin opts a Mach-policy thread out of pthread QoS;
// cleanup restores standard policy, then this dedicated sender thread exits.
class AudioDeadlineScheduler {
public:
    explicit AudioDeadlineScheduler(uint32_t frames) {
        mach_timebase_info_data_t base{};
        mach_timebase_info(&base);
        auto ticks=[&](uint64_t ns) { return uint32_t(ns*base.denom/base.numer); };
        const uint64_t periodNs=uint64_t(frames)*1000000000ULL/44100;
        period_=ticks(periodNs);
        group_=AudioWorkIntervalCreate("SpeakerHop network audio",OS_CLOCK_MACH_ABSOLUTE_TIME,nullptr);
        if(!group_) { groupResult_=-1; return; }
        groupResult_=os_workgroup_join(group_,&token_);
        if(groupResult_!=0)return;
        joined_=true;
        thread_time_constraint_policy_data_t policy{};
        policy.period=period_;
        policy.computation=ticks(std::min<uint64_t>(500000,periodNs/4));
        policy.constraint=period_;
        policy.preemptible=1;
        policyResult_=thread_policy_set(pthread_mach_thread_np(pthread_self()),
            THREAD_TIME_CONSTRAINT_POLICY,reinterpret_cast<thread_policy_t>(&policy),
            THREAD_TIME_CONSTRAINT_POLICY_COUNT);
        enabled_=policyResult_==KERN_SUCCESS;
        if(!enabled_)leave();
    }
    ~AudioDeadlineScheduler() { disable(); }
    AudioDeadlineScheduler(const AudioDeadlineScheduler&)=delete;
    AudioDeadlineScheduler& operator=(const AudioDeadlineScheduler&)=delete;

    void begin() noexcept {
        if(!enabled_)return;
        const auto now=mach_absolute_time();
        const int result=os_workgroup_interval_start(group_,now,now+period_,nullptr);
        intervalActive_=result==0;
        if(result!=0)++intervalErrors_;
    }
    void finish() noexcept {
        if(!intervalActive_)return;
        const int result=os_workgroup_interval_finish(group_,nullptr);
        intervalActive_=false;
        if(result!=0)++intervalErrors_;
    }
    bool active() noexcept {
        if(!enabled_)return false;
        thread_time_constraint_policy_data_t actual{};
        mach_msg_type_number_t count=THREAD_TIME_CONSTRAINT_POLICY_COUNT;
        boolean_t isDefault=false;
        const auto result=thread_policy_get(pthread_mach_thread_np(pthread_self()),
            THREAD_TIME_CONSTRAINT_POLICY,reinterpret_cast<thread_policy_t>(&actual),&count,&isDefault);
        if(result!=KERN_SUCCESS || isDefault || actual.period!=period_ || intervalErrors_>0) {
            // Do not repeatedly promote a thread that the system demoted.
            disable(); return false;
        }
        return true;
    }
    int policyResult() const { return policyResult_; }
    int groupResult() const { return groupResult_; }
    uint64_t intervalErrors() const { return intervalErrors_; }

private:
    void leave() noexcept {
        if(joined_) { os_workgroup_leave(group_,&token_); joined_=false; }
    }
    void disable() noexcept {
        finish();
        if(enabled_) {
            thread_policy_set(pthread_mach_thread_np(pthread_self()),THREAD_STANDARD_POLICY,nullptr,THREAD_STANDARD_POLICY_COUNT);
            enabled_=false;
        }
        leave();
    }
    os_workgroup_interval_t group_=nullptr;
    os_workgroup_join_token_s token_{};
    uint32_t period_=0;
    bool joined_=false, enabled_=false, intervalActive_=false;
    int groupResult_=-1, policyResult_=-1;
    uint64_t intervalErrors_=0;
};
