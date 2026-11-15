// SPDX-License-Identifier: Apache-2.0
#include "../Sources/AudioDeadlineScheduler.hpp"
#include <chrono>
#include <cstdio>
#include <thread>

int main() {
    bool ok=false;
    std::thread worker([&] {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE,0);
        {
            AudioDeadlineScheduler scheduling(352);
            if(!scheduling.active()) {
                std::printf("Scheduling unavailable: policy=%d group=%d\n",scheduling.policyResult(),scheduling.groupResult());
                return;
            }
            auto due=std::chrono::steady_clock::now();
            for(int i=0;i<32;++i) {
                scheduling.begin();
                // A bounded unit of arithmetic, no allocation, audio output or network.
                volatile uint64_t value=0;
                for(uint64_t n=0;n<1000;++n)value=value+n;
                scheduling.finish();
                due+=std::chrono::milliseconds(8);
                std::this_thread::sleep_until(due);
            }
            if(scheduling.intervalErrors()!=0 || !scheduling.active())return;
        }
        thread_time_constraint_policy_data_t policy{};
        mach_msg_type_number_t count=THREAD_TIME_CONSTRAINT_POLICY_COUNT;
        boolean_t isDefault=false;
        const auto result=thread_policy_get(pthread_mach_thread_np(pthread_self()),
            THREAD_TIME_CONSTRAINT_POLICY,reinterpret_cast<thread_policy_t>(&policy),&count,&isDefault);
        ok=result==KERN_SUCCESS && isDefault;
    });
    worker.join();
    std::puts(ok?"Scheduling deadlines and restoration passed":"Scheduling lifecycle failed");
    return ok?0:1;
}
