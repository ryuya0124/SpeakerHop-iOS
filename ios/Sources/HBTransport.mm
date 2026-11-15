// SPDX-License-Identifier: Apache-2.0
#import "HBTransport.h"
#import <AudioToolbox/AudioToolbox.h>
#include "raop_sender.h"
#include "raop_loop.h"
#include "ring_buffer.h"
#include <atomic>
#include <array>
#include <cmath>
#include <mutex>
#include <thread>
#include <pthread/qos.h>

namespace {
using namespace fxchain;
struct Session {
    RingBuffer<int16_t> ring{8192};
    std::atomic<bool> stop{false}, ready{false};
    std::atomic<int> state{1}, volume{-1}, rate{48000};
    std::atomic<uint64_t> frames{0}, dropped{0}, invalid{0};
    std::atomic<double> chunkMs{0}, ageMs{-1}, callbackMs{0}, intervalMs{0};
    double lastCallback = 0; // capture queue only
    std::mutex mutex;
    std::string error;
    double queuedMs=0, encodeMs=0, presentationMs=0, minimumMs=-1, maximumMs=-1;
    double leadMs=0, packetMs=0;
    uint64_t underruns=0, late=0;
    int rejection=0;
    bool fallback=false;
    std::thread worker;
    ~Session() { if(worker.joinable()) worker.join(); }
};
double hostSeconds() { return CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock())); }
}

@implementation HBTransport {
    std::shared_ptr<Session> _session;
}
- (void)connectHost:(NSString *)host port:(NSInteger)port name:(NSString *)name
          deviceID:(NSString *)deviceID sourceID:(NSString *)sourceID
    presentationMs:(NSInteger)presentation minimumMs:(NSInteger)minimum
         maximumMs:(NSInteger)maximum reserveMs:(NSInteger)reserve
      packetFrames:(NSInteger)packetFrames compressed:(BOOL)compressed {
    [self disconnect];
    auto s=std::make_shared<Session>();
    std::atomic_store(&_session, s);
    std::string address=host.UTF8String, label=name.UTF8String;
    std::string id=deviceID.UTF8String, source=sourceID.UTF8String;
    s->worker=std::thread([s,address,label,id,source,port,presentation,minimum,maximum,reserve,packetFrames,compressed] {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        try {
            RaopLoop loop;
            RaopEvents events;
            events.launched=[s](bool ok,const std::string& error) {
                { std::lock_guard lock(s->mutex); s->error=error; }
                s->state.store(ok?2:-1);
            };
            events.closed=[s] { s->state.store(-2); };
            events.pinRequired=[s](const std::string&) {
                std::lock_guard lock(s->mutex);
                s->error="HomePod requires additional pairing. Check its AirPlay access settings.";
                s->state=-1;
            };
            events.receiverRejected=[s](int code,bool) {
                std::lock_guard lock(s->mutex); s->rejection=code;
            };
            RaopSender sender(loop,std::move(events));
            sender.setStrictReceiverAuth(true);
            sender.setVolumePolicy(0,100);
            sender.setDeferInputUntilReady(true);
            sender.setCompressedAudio(compressed);
            sender.setAudioPacketFrames((uint32_t)packetFrames);
            sender.setIdentity(RaopIdentity{"SpeakerHop",source,"iPhone"});
            sender.attachRing(&s->ring);
            sender.setInputFormat(48000);
            sender.setInputBufferFrames(std::clamp((int)reserve,0,100)*48000/1000);
            sender.setPresentationLatencyMs((uint32_t)presentation);
            sender.setReceiverLatencyRangeMs((uint32_t)minimum,(uint32_t)maximum);
            sender.setAuth(RaopDeviceInfo::Auth::HapTransient,true,id,{},{});
            sender.start(address,(uint16_t)port,label);
            int rate=48000;
            bool inputReleased=false;
            auto nextStats=std::chrono::steady_clock::now();
            while(!s->stop.load() && s->state.load()>0) {
                const int newRate=s->rate.load();
                if(rate!=newRate) {
                    rate=newRate; sender.setInputFormat(rate);
                    sender.setInputBufferFrames(std::clamp((int)reserve,0,100)*rate/1000);
                }
                if(!inputReleased && s->frames.load()>0) {
                    sender.releaseInput(); inputReleased=true;
                }
                int volume=s->volume.exchange(-1);
                if(volume>=0) sender.setVolume(volume);
                // No staging queue, one deadline-driven network thread; 1 ms maximum idle poll.
                loop.pump(sender,std::chrono::milliseconds(1));
                s->ready=sender.transportReady();
                auto now=std::chrono::steady_clock::now();
                if(now>=nextStats) {
                    std::lock_guard lock(s->mutex);
                    s->queuedMs=1000.0*s->ring.availableRead()/2/rate;
                    s->encodeMs=sender.maximumEncodeMicros()/1000.0;
                    s->presentationMs=sender.presentationLatencyFrames()*1000.0/44100;
                    s->minimumMs=sender.receiverMinimumLatencyFrames()<0?-1:sender.receiverMinimumLatencyFrames()*1000.0/44100;
                    s->maximumMs=sender.receiverMaximumLatencyFrames()<0?-1:sender.receiverMaximumLatencyFrames()*1000.0/44100;
                    s->leadMs=sender.lastHandoffLeadMicros()/1000.0;
                    s->packetMs=sender.audioPacketFrames()*1000.0/44100;
                    s->underruns=sender.inputUnderrunFrames();
                    s->late=sender.lateHandoffPackets();
                    s->fallback=sender.latencyCompatibilityFallback();
                    nextStats=now+std::chrono::milliseconds(200);
                }
            }
            sender.setVolume(0);
            sender.stop();
        } catch(const std::exception& e) {
            std::lock_guard lock(s->mutex); s->error=e.what(); s->state=-1;
        }
    });
}
- (void)appendSampleBuffer:(CMSampleBufferRef)buffer clock:(CMClockRef)clock {
    auto s=std::atomic_load(&_session);
    if(!s || s->stop.load() || !s->ready.load()) return;
    const double began=hostSeconds();
    if(s->lastCallback>0) s->intervalMs=(began-s->lastCallback)*1000;
    s->lastCallback=began;
    auto fmt=CMSampleBufferGetFormatDescription(buffer);
    const auto *asbd=fmt?CMAudioFormatDescriptionGetStreamBasicDescription(fmt):nullptr;
    auto n=CMSampleBufferGetNumSamples(buffer);
    if(!asbd || asbd->mFormatID!=kAudioFormatLinearPCM || n<=0 || n>4096 ||
       asbd->mChannelsPerFrame<1 || asbd->mChannelsPerFrame>2 ||
       (asbd->mSampleRate!=44100 && asbd->mSampleRate!=48000)) { ++s->invalid; return; }
    const bool floating=asbd->mFormatFlags&kAudioFormatFlagIsFloat;
    const bool signedInt=asbd->mFormatFlags&kAudioFormatFlagIsSignedInteger;
    if((floating && asbd->mBitsPerChannel!=32) || (!floating && (!signedInt || asbd->mBitsPerChannel!=16)) ||
       (asbd->mFormatFlags&kAudioFormatFlagIsBigEndian)) { ++s->invalid; return; }
    struct { AudioBufferList list; AudioBuffer extra; } storage{};
    CMBlockBufferRef retained=nullptr;
    OSStatus result=CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(buffer,nullptr,&storage.list,
        sizeof(storage),nullptr,nullptr,kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,&retained);
    if(result!=noErr) { ++s->invalid; return; }
    std::array<int16_t,8192> pcm;
    const bool planar=asbd->mFormatFlags&kAudioFormatFlagIsNonInterleaved;
    const unsigned channels=asbd->mChannelsPerFrame;
    bool valid=storage.list.mNumberBuffers>=(planar?channels:1);
    for(unsigned b=0;valid && b<(planar?channels:1);++b) {
        const auto& ab=storage.list.mBuffers[b];
        valid=ab.mData && ab.mDataByteSize>=n*(floating?4:2)*(planar?1:channels);
    }
    if(valid) {
        for(CMItemCount f=0;f<n;++f) for(unsigned ch=0;ch<2;++ch) {
            unsigned channel=std::min(ch,channels-1);
            const auto& ab=storage.list.mBuffers[planar?channel:0];
            size_t index=planar?f:f*channels+channel;
            if(floating) {
                float v=((const float*)ab.mData)[index];
                pcm[f*2+ch]=std::isfinite(v)?(int16_t)std::lrint(std::clamp(v,-1.0f,1.0f)*32767):0;
            } else pcm[f*2+ch]=((const int16_t*)ab.mData)[index];
        }
        s->rate=(int)asbd->mSampleRate;
        // Bound stale audio: discard new input on overload rather than accumulating seconds of delay.
        if(s->ring.availableRead()>asbd->mSampleRate*2*0.04 || !s->ring.tryPush({pcm.data(),(size_t)n*2}))
            s->dropped.fetch_add(n);
        else s->frames.fetch_add(n);
        s->chunkMs=n*1000.0/asbd->mSampleRate;
        if(clock) {
            CMTime hostPTS=CMSyncConvertTime(CMSampleBufferGetPresentationTimeStamp(buffer),clock,CMClockGetHostTimeClock());
            const double age=(began-CMTimeGetSeconds(hostPTS))*1000;
            s->ageMs=std::isfinite(age) && age>=0 && age<5000?age:-1;
        }
    } else ++s->invalid;
    if(retained) CFRelease(retained);
    s->callbackMs=(hostSeconds()-began)*1000;
}
- (void)setVolume:(NSInteger)volume {
    auto s=std::atomic_load(&_session);
    if(s) s->volume=(int)std::clamp((int)volume,0,100);
}
- (void)disconnect {
    auto s=std::atomic_exchange(&_session,std::shared_ptr<Session>{});
    if(s) { s->stop=true; if(s->worker.joinable()) s->worker.join(); }
}
- (NSDictionary<NSString *,id> *)snapshot {
    auto s=std::atomic_load(&_session);
    if(!s) return @{@"state":@0};
    std::lock_guard lock(s->mutex);
    return @{@"state":@(s->state.load()),@"ready":@(s->ready.load()),@"error":@(s->error.c_str()),
      @"frames":@(s->frames.load()),@"dropped":@(s->dropped.load()),@"invalid":@(s->invalid.load()),
      @"captureAge":@(s->ageMs.load()),@"captureChunk":@(s->chunkMs.load()),
      @"callback":@(s->callbackMs.load()),@"interval":@(s->intervalMs.load()),
      @"queue":@(s->queuedMs),@"encode":@(s->encodeMs),@"presentation":@(s->presentationMs),
      @"minimum":@(s->minimumMs),@"maximum":@(s->maximumMs),@"lead":@(s->leadMs),@"packetMs":@(s->packetMs),
      @"underruns":@(s->underruns),@"late":@(s->late),@"rejection":@(s->rejection),@"fallback":@(s->fallback)};
}
- (void)dealloc { [self disconnect]; }
@end
