Requires a compatible HomePod and an iOS/iPadOS 27 physical device on the same local network. A simulator supports layout inspection only; ScreenCaptureKit audio capture is unavailable in the simulator SDK.

1. Allow Local Network access, then search for speakers.
2. Select a HomePod and tap Share device audio.
3. Approve whole-screen sharing in the system-owned picker. No microphone/camera capture is requested.
4. Start an eligible audio source. Connections start muted; raise HomePod volume carefully with the app's slider. Device-local playback volume is separate.
5. Use the Stable profile if playback is interrupted or distorted with the experimental 45 ms target. Both presets use standard 352-frame packets; shorter packets are optional in Manual. Stop sharing before changing profiles.

The app uses ScreenCaptureKit's public audio output and the public screen-capture/audio background execution modes for network audio streaming. Its playback session uses mixWithOthers so starting sharing does not interrupt or duck the source app. It does not hook other apps, use private audio routing APIs, or require jailbreak. Protected content, calls and some source apps may be excluded by iOS. The standard system-volume control changes local system output; SpeakerHop does not automatically mute another app's audio session.

Displayed capture and queue timings are separate measurements; configured receiver values are not acoustic latency measurements. No fixed end-to-end latency is advertised. App Store review submission is outside the current draft-registration request.
