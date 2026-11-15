// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import MediaPlayer

struct DevicePlaybackControls: View {
    @ObservedObject var session: SharingAudioSession
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Other apps may play simultaneously", systemImage: "speaker.wave.2")
            HStack {
                Text("System output volume")
                Spacer()
                Text("\(Int(session.deviceVolume * 100))%") .monospacedDigit()
            }
            SystemVolumeControl().frame(height: 32)
            Text("This is the system volume, separate from the HomePod slider. iOS does not let SpeakerHop automatically mute other apps. If lowering this also silences capture, restore it and use the HomePod slider for listening volume.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct SystemVolumeControl: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsVolumeSlider = true
        return view
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
