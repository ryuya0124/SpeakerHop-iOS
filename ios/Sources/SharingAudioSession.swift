// SPDX-License-Identifier: Apache-2.0
import AVFAudio
import Foundation

final class SharingAudioSession: ObservableObject {
    @Published private(set) var deviceVolume: Float = 0
    @Published private(set) var outputName = ""
    private let session = AVAudioSession.sharedInstance()
    private var observation: NSKeyValueObservation?
    private var routeObserver: NSObjectProtocol?
    private(set) var active = false

    init() {
        deviceVolume = session.outputVolume
        outputName = session.currentRoute.outputs.first?.portName ?? ""
        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            DispatchQueue.main.async {
                guard let self, let volume = change.newValue, self.deviceVolume != volume else { return }
                self.deviceVolume = volume
            }
        }
        routeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.outputName = self.session.currentRoute.outputs.first?.portName ?? ""
        }
    }

    func begin() throws {
        // Do not interrupt, duck or silence the source app's audio session.
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setPreferredIOBufferDuration(0.002)
        try session.setActive(true)
        active = true
    }

    func end() {
        guard active else { return }
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        active = false
    }

    var report: [String: Any] {
        ["systemVolume": session.outputVolume, "mixWithOthers": session.categoryOptions.contains(.mixWithOthers),
         "audioSessionActive": active, "ioBufferMs": session.ioBufferDuration * 1000,
         "sessionMuted": session.isOutputMuted]
    }

    deinit { if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) } }
}
