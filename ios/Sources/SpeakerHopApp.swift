// SPDX-License-Identifier: Apache-2.0
import SwiftUI

@main
struct SpeakerHopApp: App {
    @StateObject private var bridge = BridgeModel()
    @StateObject private var discovery = Discovery()
    var body: some Scene {
        WindowGroup { MainView().environmentObject(bridge).environmentObject(discovery) }
    }
}

struct MainView: View {
    @EnvironmentObject var bridge: BridgeModel
    @EnvironmentObject var discovery: Discovery
    @State private var selectedTab = "share"
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Share", systemImage: "homepodmini.fill", value: "share") { share }
            Tab("Latency", systemImage: "waveform.path", value: "latency") { settings }
            Tab("Diagnostics", systemImage: "chart.xyaxis.line", value: "diagnostics") { diagnostics }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(.teal)
        .onOpenURL { url in
            if url.scheme == "speakerhop", let page = url.host,
                ["share", "latency", "diagnostics"].contains(page) { selectedTab = page }
        }
    }

    private var share: some View {
        NavigationStack {
            Form {
                Section("Speaker") {
                    ForEach(discovery.speakers) { speaker in
                        Button {
                            bridge.selected = speaker
                        } label: {
                            HStack {
                                Image(systemName: "homepodmini.fill")
                                Text(speaker.name).foregroundStyle(.primary)
                                Spacer()
                                if bridge.selected?.id == speaker.id { Image(systemName: "checkmark.circle.fill").accessibilityLabel("Selected") }
                            }
                        }.disabled(bridge.connected || bridge.connecting)
                    }
                    if discovery.speakers.isEmpty {
                        ContentUnavailableView("Find your HomePod", systemImage: "homepodmini", description: Text("Connect to the same Wi-Fi network, then search for speakers."))
                    }
                    Button(LocalizedStringKey(discovery.searching ? "Search again" : "Search for speakers"), systemImage: "arrow.clockwise") { discovery.start() }
                        .disabled(bridge.connected || bridge.connecting)
                    if !discovery.message.isEmpty { Text(discovery.message).foregroundStyle(.secondary) }
                }
                Section {
                    Label(bridge.status, systemImage: bridge.capturing ? "waveform" : "speaker.slash")
                    if bridge.connecting || bridge.connected {
                        Button("Stop sharing", role: .destructive) { bridge.stop() }
                    } else {
                        Button("Share device audio", systemImage: "airplay.audio") { bridge.start() }
                            .disabled(bridge.selected == nil)
                    }
                } footer: {
                    Text("Choose the entire screen in the system sharing dialog. Only audio is sent to your HomePod. Microphone and camera are excluded. Protected content and calls may be unavailable.")
                }
                Section("HomePod volume") {
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: Binding(get: { bridge.volume }, set: { bridge.updateVolume($0) }), in: 0...100, step: 1)
                        Text("\(Int(bridge.volume))%") .monospacedDigit().frame(minWidth: 45)
                    }.disabled(!bridge.connected)
                    Text(LocalizedStringKey(bridge.connected ? "Each new connection starts muted." : "Connect a speaker to change its volume."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Device playback") {
                    Text("The device speaker uses its own volume. Lower it with the device volume buttons if you only want to hear HomePod.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !bridge.error.isEmpty { Section("Sharing stopped") { Text(bridge.error).foregroundStyle(.red) } }
            }.navigationTitle("SpeakerHop")
        }
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    Picker("Profile", selection: Binding(get: { bridge.profile }, set: { bridge.applyProfile($0) })) {
                        Text("Lowest latency").tag(0)
                        Text("Stable").tag(1)
                        Text("Manual").tag(2)
                    }.pickerStyle(.segmented)
                    Text("Settings apply to the next connection. iOS controls the capture callback size; the app adds no extra capture queue.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("HomePod timing") {
                    numeric("Presentation target", value: $bridge.presentation, range: 45...2000)
                    numeric("Receiver minimum", value: $bridge.receiverMinimum, range: 45...2000)
                    numeric("Receiver maximum", value: $bridge.receiverMaximum, range: bridge.receiverMinimum...2000)
                }
                Section("Sender") {
                    numeric("Extra input reserve", value: $bridge.reserve, range: 0...100)
                    Picker("Packet length", selection: $bridge.packetFrames) {
                        Text("1 ms · 44 frames").tag(44)
                        Text("2 ms · 88 frames").tag(88)
                        Text("8 ms · 352 frames").tag(352)
                    }
                    Toggle("Lossless compression", isOn: $bridge.compressed)
                    Text("Compression remains optional. Short packets are experimental; receiver compatibility is shown in Diagnostics.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .disabled(bridge.profile != 2)
            }
            .disabled(bridge.connecting || bridge.connected)
            .onDisappear { bridge.saveSettings() }
            .onChange(of: [bridge.presentation, bridge.receiverMinimum, bridge.receiverMaximum,
                bridge.reserve, Double(bridge.packetFrames), bridge.compressed ? 1 : 0]) { bridge.saveSettings() }
            .navigationTitle("Latency")
        }
    }

    private func numeric(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack { Text(LocalizedStringKey(title)); Spacer(); Text("\(Int(value.wrappedValue)) ms").monospacedDigit() }
            Slider(value: value, in: range, step: 1)
        }.disabled(bridge.profile != 2)
    }

    private var diagnostics: some View {
        NavigationStack {
            Form {
                Section("Measured on this device") {
                    metric("Capture delivery age", "captureAge")
                    metric("Capture block span", "captureChunk")
                    metric("Capture callback interval", "interval")
                    metric("PCM conversion", "callback")
                    metric("Sender queue", "queue")
                    metric("Actual packet span", "packetMs")
                    metric("Maximum encode time", "encode")
                }
                Section("Receiver negotiation") {
                    metric("Applied presentation target", "presentation")
                    metric("Receiver reported minimum", "minimum")
                    metric("Receiver reported maximum", "maximum")
                    metric("Latest send deadline lead", "lead")
                    LabeledContent("Setup rejection", value: String((bridge.stats["rejection"] as? NSNumber)?.intValue ?? 0))
                    LabeledContent("Compatibility fallback", value: (bridge.stats["fallback"] as? Bool) == true ? String(localized: "Active") : String(localized: "No"))
                }
                Section("Stream health") {
                    ForEach([("Captured frames", "frames"), ("Dropped frames", "dropped"), ("Invalid audio blocks", "invalid"), ("Missing input frames", "underruns"), ("Late packets", "late")], id: \.1) { label, key in
                        LabeledContent(LocalizedStringKey(label), value: String((bridge.stats[key] as? NSNumber)?.uint64Value ?? 0))
                    }
                    Text("These measurements do not establish acoustic end-to-end latency. Receiver targets and reported bounds are settings, not measurements of speaker playback. Capture block span overlaps delivery age; do not add them together.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Diagnostics")
        }
    }

    private func metric(_ name: String, _ key: String) -> some View {
        let value = (bridge.stats[key] as? NSNumber)?.doubleValue
        return LabeledContent(LocalizedStringKey(name), value: value.map { $0 < 0 ? String(localized: "Unavailable") : String(format: "%.2f ms", $0) } ?? "—")
    }
}
