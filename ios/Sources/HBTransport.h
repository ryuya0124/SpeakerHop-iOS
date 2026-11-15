// SPDX-License-Identifier: Apache-2.0
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
NS_ASSUME_NONNULL_BEGIN
// Lifecycle is main-thread owned; PCM delivery is confined to one capture queue.
@interface HBTransport : NSObject
- (void)connectHost:(NSString *)host port:(NSInteger)port name:(NSString *)name
          deviceID:(NSString *)deviceID sourceID:(NSString *)sourceID
    presentationMs:(NSInteger)presentation minimumMs:(NSInteger)minimum
         maximumMs:(NSInteger)maximum reserveMs:(NSInteger)reserve
      packetFrames:(NSInteger)packetFrames compressed:(BOOL)compressed;
- (void)appendSampleBuffer:(CMSampleBufferRef)buffer clock:(nullable CMClockRef)clock;
- (void)setVolume:(NSInteger)volume;
- (void)disconnect;
- (NSDictionary<NSString *, id> *)snapshot;
@end
NS_ASSUME_NONNULL_END
