# SpeakerHop for iOS

Share eligible device audio with a HomePod on your local network. Native SwiftUI app for iPhone, iPad and iPhone Duo, using iOS/iPadOS 27 public screen-audio capture APIs. No jailbreak or Mac relay is required for playback.

The project prioritizes low latency with no extra capture staging queue, independently configurable sender/receiver timing, optional lossless compression and separate pipeline diagnostics. Device connections start muted. Protected content, calls and some apps may be excluded by iOS.

**Development status:** initial experimental implementation. Simulator builds verify the interface only; physical capture, audible playback and acoustic latency must be validated separately. No fixed end-to-end latency or App Store acceptance is claimed.

See [iOS build and architecture notes](ios/README.md), [store metadata drafts](ios/appstore/metadata.json), and [privacy policy](ios/appstore/privacy.md).

## Provenance

The standalone C++ AirPlay sender is imported from [OneUI-Mods/HomePodBridge](https://github.com/OneUI-Mods/HomePodBridge) commit `1b111eeaed7fbfcc90f4d23f61064fdfe7cc3aa9`, including its HomePod timing and metadata changes. Source and third-party license notices are retained under `third_party/airplay2-sender-cpp`. This repository does not include the Android app or its SystemUI/HAL hooks.

SpeakerHop is independent of Apple. HomePod and AirPlay are Apple Inc. trademarks used to identify compatibility.
