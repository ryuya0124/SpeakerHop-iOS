# SpeakerHop for iOS and iPadOS

Native SwiftUI universal app for iPhone, iPad, and iPhone Duo. Requires iOS/iPadOS 27. No jailbreak, private audio hooks, or broadcast extension. ScreenCaptureKit is unavailable in the simulator SDK; simulator builds support UI/layout validation only and cannot establish audio capture success.

## Build

Work directly under Documents, for example `~/Documents/SpeakerHop`.

```sh
cd ios
bundle install
bundle exec fastlane ios device
```

Dependencies: Xcode 27+, XcodeGen, CMake, Ruby and fastlane. Existing development signing must be available in the Mac keychain. No signing material belongs in the repository. For an Apple Silicon simulator build, run `bundle exec fastlane ios simulator`. Metadata preparation and draft upload use the separate fastlane lanes; neither submits a review.

## Audio path

System sharing picker → ScreenCaptureKit audio-only output → direct bounded PCM conversion → SPSC ring → existing authenticated AirPlay 2 sender → HomePod. No microphone or camera output, video file, proxy Mac, or cloud relay is used by the app. The Mac is for building/debugging only.

Each connection starts at 0%; the user-facing control supports 0–100%. Assistant listening tests are restricted to 20%. Consent cancellation, receiver disconnect, or capture failure stops sharing. Outputs retain their own connection so late callbacks cannot feed a later session. The stream runs using the public screen-capture/audio background modes and a mixable playback session, allowing other apps to continue playing without being ducked or interrupted by SpeakerHop.

Starting with development build 4, the timing profiles are:

| Profile | Presentation/receiver target | Additional input reserve |
| --- | --- | --- |
| Stable (initial default) | 1000 ms | 100 ms |
| Low latency | 500 ms | 50 ms |
| Ultra low | 45 ms | 2 ms |
| Manual | Independently adjustable | Independently adjustable |

Presets use 352-frame (~8 ms) packets and uncompressed ALAC framing. Ultra low inherits the previous low-latency settings; existing saved selections migrate to that name. It is experimental and **not an iOS latency measurement or a guarantee of continuous playback**. Manual also permits shorter 44/88-frame packets within the documented bounds. Settings persist; volume never resumes automatically. The submitted TestFlight build 3 retains its original Stable/Lowest latency/Manual choices.

iOS chooses capture block duration; 20 ms blocks have been observed on the test iPhone. Splitting a completed block does not make its earlier samples arrive sooner. The sender waits on socket activity or its next absolute packet deadline instead of waking every millisecond between packets. After a prolonged stall, it discards only expired input and catches up audio still inside the receiver's presentation window, preserving fractional resampling phase. The bounded capture ring retains fresh input during stalls. The consumer enforces a maximum queued-input duration of presentation target + input reserve + 20 ms, after deadline recovery; this is a retention limit, not an additional prefill or fixed delay. Diagnostics distinguish producer overflow, expired timeline frames, and source frames trimmed to the queue limit. They also separate capture timestamp age, block span, callback work, queue depth including resampler staging, encoding maximum, negotiated receiver bounds, rejection, late packets and stall recovery. A negative deadline lead is displayed as a negative value. Do not sum overlapping measurements or label requested receiver timing as acoustic end-to-end latency.

Capture explicitly requests the supported native 48 kHz rate, with the sender converting once to the receiver's 44.1 kHz stream. Extra reserve uses the actual source sample rate. Lowest latency also requests Darwin's public per-socket audio/video streaming service class; it is optional and never marks the app as a VoIP service. Diagnostics read back the applied socket class and control TCP RTT. TCP RTT is not UDP one-way or acoustic delay; a sub-millisecond value rounded to zero by Darwin is shown as unavailable rather than as zero latency. Socket priority does not guarantee network or capture latency.

Source audio remains subject to iOS capture policy: protected media, calls and some apps may be excluded. Screen capture does not promise to mute the source device's local speaker; check local output separately during listening tests. Screen sharing needs explicit system consent, and Local Network permission is needed for discovery/transport.

The dedicated sender thread requests a public Audio Workgroup and a preemptible Mach audio deadline only after authentication and source input. The CPU budget is capped at 0.5 ms per packet period (or one quarter of a shorter period). If unavailable or demoted, it falls back to standard scheduling; cleanup restores standard policy before the dedicated thread exits. This does not reconfigure an audio device or system service. Diagnostics show the actual scheduling status. Host smoke tests verify interval operation and restoration; these are not proof of uninterrupted iOS playback.

## Adaptive UI

SwiftUI `TabView` with `.sidebarAdaptable`, `NavigationStack` and resizable Forms; no fixed device width, main-screen singleton or interface-idiom branching. iPhone Duo inner/outer display layouts and iPad resizing are supported by the same view tree. Deep links `speakerhop://share`, `speakerhop://latency`, and `speakerhop://diagnostics` select views only; they cannot start capture, connect, or change volume.

## App Store preparation

Metadata drafts are in `appstore/`. Keep the record in Prepare for Submission; creating a draft does not authorize review submission or release. Only upload screenshots of the actual app. Do not claim capture of all apps, fixed end-to-end latency, verified iPhone Duo hardware behavior, or App Store approval without evidence. Encryption export-compliance answers must reflect the bundled AirPlay cryptography rather than assuming system TLS only.

The editable store record is [SpeakerHop](https://appstoreconnect.apple.com/apps/6835134732/distribution). Japanese/English descriptions and twelve screenshots have been uploaded and read back. Version 0.1.0 build 3 was submitted to TestFlight Beta App Review, and assigned to external `main` and internal `internal`. The account owner was registered as an internal tester. [The external invitation](https://testflight.apple.com/join/96JZsDTg) becomes usable for the build after Apple's approval. App Store customer release and App Store App Review remain outside the current authorization.

`archive_beta`, `store_profile` and `beta_upload` prepare the unsigned archive, reuse the existing distribution identity/profile and upload the explicitly supplied signed IPA. Upload authentication is separate from developer-portal login. Supply an existing API-key JSON as `api_key_path:` to `beta_upload`. The optional terminal helper can register an application-specific upload password on the Mac; secrets must not be pasted into chat or stored in Git. The current encryption-document exemption is based on standard cryptography without proprietary algorithms and the user's explicit decision not to distribute on the French App Store during this TestFlight-only rollout; reassess before changing that distribution scope.
