# Development status — 2026-11-16

## Scope and distribution

Standalone iOS repository: `ryuya0124/SpeakerHop-iOS`, separate from OneUI-Mods/HomePodBridge. Workspaces are `Documents/SpeakerHop` on Windows and Mac. The app's working name is SpeakerHop; bundle ID is `dev.ryuya.speakerhop`. No Apple product name is used in its app name, identifier or hardware-independent waveform icon. In-app HomePod symbols identify the compatible receiver.

Use fastlane, with the checked-in Gemfile.lock. The observed environment is Xcode 27.2, iPhoneOS/Simulator SDK 27.2 and fastlane 2.241.2. No jailbreak or other-app hooks are involved. ScreenCaptureKit's iOS 27 public capture API is absent from the simulator SDK, so the simulator compiles the same SwiftUI interface with capture unavailable. It cannot prove capture or playback.

## Validation completed

- fastlane Release builds succeeded for physical iOS and Apple Silicon simulators.
- Existing development identity/profile were validated, and fastlane `resign` produced an IPA whose application passed strict codesign verification. Installed on the paired iPhone and iPad; confirmed iPhone launch. The iPad was locked during its initial launch check, so no iPad runtime-capture result is claimed.
- macOS native protocol, codec, timing and real loopback socket suites: 4/4 passed, including readback of Darwin multimedia service class and isolation after disabling priority. Linux native CI passed for the initial implementation; rerun it after subsequent transport changes.
- UI screenshots use fastlane `scan`, XCUITest navigation-bar/foreground assertions and xcresult attachments. Three owned simulators each passed the screen-capture test, producing 18 actual app screenshots: Share, Latency and Diagnostics in English/Japanese for iPhone, iPad and iPhone Duo outer display. Earlier shell-only captures included system prompts/launch animations and were replaced; do not upload those earlier files.
- The final waveform icon is a 1024×1024 opaque RGB PNG, visually inspected and checked for nonempty image content. A preliminary AppKit bitmap generator produced black output; it was replaced with an explicitly validated Core Graphics context.

Current screenshots are under `ios/build/store-screenshots` (12 required iPhone/iPad images) and `ios/build/duo-layouts` (6 outer-display layout images) on the Mac. They are development artifacts, not evidence of active audio. New diagnostic fields may require refreshing the screenshot set before a final store upload.

## Latency design

ScreenCaptureKit audio-only callbacks convert PCM directly into a bounded SPSC ring. There is no video encoder, recording file, cloud relay, Mac relay or extra callback staging queue. Requested capture rate is a supported native 48 kHz; conversion to the receiver's 44.1 kHz occurs once in the sender. Extra reserve uses actual source-rate frames. Lowest latency requests no extra reserve, 88-frame packets and independent 45 ms receiver/presentation targets; manual also offers 44-frame packets. Compression is optional and disabled initially.

The 45 ms minimum comes from this user's Android/HomePod observations, not an iOS acoustic measurement. The operating system chooses capture callback period. A 1 ms maximum idle poll and short packets do not establish 1 ms capture or transmission latency. Source callbacks can already contain older samples; splitting a delivered block does not make them arrive earlier.

Optional Darwin `SO_NET_SERVICE_TYPE/NET_SERVICE_TYPE_AV` applies only to this sender's UDP sockets and is read back for diagnostics. It does not request the VoIP class, change router settings or alter global traffic policy. Native TCP RTT has millisecond granularity; rounded-zero samples remain unavailable, rather than implying zero delay. TCP RTT is not UDP one-way latency.

Diagnostics separate delivery age, capture block span/interval, callback work, queue depth, actual packet span, encoding maximum, socket-call time, TCP RTT, receiver bounds, deadline lead, refusal/fallback and stream counters. Peak/nonzero input counters distinguish silence from real input without saving PCM. Last measurements survive a disconnect; the exported diagnostic current-state fields identify whether a connection/capture is still active.

Each connection starts muted and requires the initial mute acknowledgement before audio. Application volume supports 0–100%; assistant listening tests are limited to 20%. No audible source has been started during this iOS work.

## Remaining physical verification

The iPhone is available for testing. The user was asked to search/select their speaker in SpeakerHop and approve whole-screen sharing in the system picker, with volume still at zero. No reply confirming this action has arrived yet. The last exported diagnostic report contained no connection or capture measurements. Discovery, iOS-to-HomePod handshake, actual capture, audible playback at 20%, background continuity and acoustic end-to-end latency remain unverified. Do not claim a measured improvement, working all-app capture or audible success from compilation, simulator screenshots or protocol tests.

iPhone Duo outer-display UI was checked at 1398×2034. The inner display and hinge transition remain unverified; standard adaptive SwiftUI layout is implemented, but no physical Duo is connected. Device Hub owns the hinge posture: powering off a simulated display is not an equivalent fold test. Mac desktop-operation tooling was not installed, so no Device Hub pose interaction was performed.

## Signing from SSH

The initial codesign failure was SSH Security-session access, not proof that the login keychain was locked. MochiLog's existing work record documents successful signing from the logged-in Mac session. An isolated Aqua-session background signing probe succeeded without changing keys, ACLs, certificate trust or passwords.

For this run, fastlane built the Release app unsigned in Documents. A matching, unexpired existing development profile containing the authorized device and identity was selected without exposing its contents. A derived IPA/profile/entitlements were staged under the user's private Library/Caches signing directory; a temporary per-user Aqua launch job ran fastlane `resign`. Strict codesign verification preceded device installation through the `install_device` lane. Temporary launch jobs were unloaded afterward. Credentials and private device values are absent from this repository.

## App Store Connect

English/Japanese metadata, privacy policy, review notes and verified UI screenshot preparation exist. `prepare_metadata` generates the deliver directory. `create_draft` uses produce; `upload_draft` uploads metadata/screenshots with binary upload, automatic release and review submission disabled. No production submission lane is provided.

**The App Store Connect record has not been created or updated yet.** The user requested registration after completion; actual audio behavior must be verified first. Existing Mac developer-account authentication can be reused through fastlane, but current App Store Connect session validity is not established. Do not silently submit agreements, claim export-encryption exemption, submit review, release the app or invent missing review/contact information. The bundled non-system AirPlay cryptography must be accurately reflected when export-compliance information is eventually completed.
