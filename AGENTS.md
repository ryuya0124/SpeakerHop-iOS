# SpeakerHop iOS development

- Work directly under Documents, outside the Codex folder. This repository is separate from the Android HomePod Bridge repository.
- Use SwiftUI for iPhone, iPad and iPhone Duo. Adapt to available space, resizing and display transitions rather than fixed device widths.
- No jailbreak, private audio APIs, hooks into other apps or bypasses of system sharing consent. Target iOS/iPadOS 27 using ScreenCaptureKit's public audio output.
- Minimize real capture-to-send delay. Keep capture period, packet duration, sender queue and receiver targets separately adjustable or measurable where the OS permits. Do not equate configured timing with measured acoustic latency.
- Physical-device debugging is authorized. Start every connection muted; audible assistant tests are limited to 20%. The application itself supports 0–100% volume.
- Use fastlane for builds and App Store preparation. The user requested an App Store Connect draft, descriptions and screenshots; this does not authorize review submission or release.
- Keep credentials, signing keys, auth cookies, private device identifiers and raw device diagnostics outside Git and tool output. Reuse existing signing identities; do not revoke or replace unrelated certificates.
- Preserve licenses and provenance for the reused C++ sender. Avoid changing global audio policy or unrelated projects.
