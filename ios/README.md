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

Each connection starts at 0%; the user-facing control supports 0–100%. Assistant listening tests are restricted to 20%. Consent cancellation, receiver disconnect, or capture failure stops sharing. Outputs retain their own connection so late callbacks cannot feed a later session. The stream runs using the public `screen-capture` background mode.

The lowest-latency profile requests 45 ms presentation/receiver bounds, 0 ms additional reserve, 88-frame (~2 ms) packets and uncompressed ALAC framing. This is an experimental configuration carried over from the user's Android/HomePod observations; it is **not an iOS latency measurement or a guarantee of audible playback**. Stable uses 250 ms and 352-frame packets. Manual permits independent values within the documented bounds. Settings persist; volume never resumes automatically.

iOS chooses capture block duration. Splitting a completed block does not make its earlier samples arrive sooner. The sender pumps deadlines with at most 1 ms idle polling; this does not mean a 1 ms capture or network path. Diagnostics separate capture timestamp age, block span, callback work, queue depth, encoding maximum, negotiated receiver bounds, rejection, and late packets. Do not sum overlapping measurements or label requested receiver timing as acoustic end-to-end latency.

Capture explicitly requests the supported native 48 kHz rate, with the sender converting once to the receiver's 44.1 kHz stream. Extra reserve uses the actual source sample rate. Lowest latency also requests Darwin's public per-socket audio/video streaming service class; it is optional and never marks the app as a VoIP service. Diagnostics read back the applied socket class and control TCP RTT. TCP RTT is not UDP one-way or acoustic delay; a sub-millisecond value rounded to zero by Darwin is shown as unavailable rather than as zero latency. Neither socket priority nor 1 ms polling guarantees a network or capture latency.

Source audio remains subject to iOS capture policy: protected media, calls and some apps may be excluded. Screen capture does not promise to mute the source device's local speaker; check local output separately during listening tests. Screen sharing needs explicit system consent, and Local Network permission is needed for discovery/transport.

## Adaptive UI

SwiftUI `TabView` with `.sidebarAdaptable`, `NavigationStack` and resizable Forms; no fixed device width, main-screen singleton or interface-idiom branching. iPhone Duo inner/outer display layouts and iPad resizing are supported by the same view tree. Deep links `speakerhop://share`, `speakerhop://latency`, and `speakerhop://diagnostics` select views only; they cannot start capture, connect, or change volume.

## App Store preparation

Metadata drafts are in `appstore/`. Keep the record in Prepare for Submission; creating a draft does not authorize review submission or release. Only upload screenshots of the actual app. Do not claim capture of all apps, fixed end-to-end latency, verified iPhone Duo hardware behavior, or App Store approval without evidence. Encryption export-compliance answers must reflect the bundled AirPlay cryptography rather than assuming system TLS only.
