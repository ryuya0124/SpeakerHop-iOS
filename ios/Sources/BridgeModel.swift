// SPDX-License-Identifier: Apache-2.0
import Foundation
import CoreMedia
import UIKit
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit

private final class CaptureSink: NSObject, SCStreamOutput {
    let transport: HBTransport
    init(transport: HBTransport) { self.transport = transport }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        transport.append(sampleBuffer, clock: stream.synchronizationClock)
    }
}
#endif

final class BridgeModel: NSObject, ObservableObject {
    @Published var selected: Speaker?
    @Published var status = String(localized: "Not connected")
    @Published var capturing = false
    @Published var connecting = false
    @Published var connected = false
    @Published var volume = 0.0
    let telemetry = TelemetryStore()
    let audioSession = SharingAudioSession()
    var stats: [String: Any] { telemetry.values }
    @Published var error = ""
    @Published var profile = 0
    @Published var presentation = 45.0
    @Published var receiverMinimum = 45.0
    @Published var receiverMaximum = 45.0
    @Published var reserve = 2.0
    @Published var packetFrames = 352
    @Published var compressed = false
    @Published var networkPriority = true
    private var transport = HBTransport()
    private let audioQueue = DispatchQueue(label: "dev.ryuya.speakerhop.capture", qos: .userInteractive)
#if canImport(ScreenCaptureKit)
    private var captureSink: CaptureSink?
    private var stream: SCStream?
#endif
    private var timer: Timer?
    private let diagnosticQueue = DispatchQueue(label: "dev.ryuya.speakerhop.diagnostics", qos: .utility)
    private var pickerRegistered = false
    private var stopping = false
    private let sourceID: String

    override init() {
        if let existing = UserDefaults.standard.string(forKey: "senderDeviceID") {
            sourceID = existing
        } else {
            var bytes = (0..<6).map { _ in UInt8.random(in: 0...255) }
            bytes[0] = (bytes[0] | 2) & 254
            sourceID = bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
            UserDefaults.standard.set(sourceID, forKey: "senderDeviceID")
        }
        super.init()
        if let saved = UserDefaults.standard.dictionary(forKey: "timingSettings") {
            profile = min(2, max(0, saved["profile"] as? Int ?? 0))
            presentation = min(2000, max(45, saved["presentation"] as? Double ?? 45))
            receiverMinimum = min(2000, max(45, saved["minimum"] as? Double ?? 45))
            receiverMaximum = min(2000, max(receiverMinimum, saved["maximum"] as? Double ?? 45))
            reserve = min(100, max(0, saved["reserve"] as? Double ?? 0))
            let frames = saved["packet"] as? Int ?? 352
            packetFrames = [44, 88, 352].contains(frames) ? frames : 352
            compressed = saved["compressed"] as? Bool ?? false
            networkPriority = saved["networkPriority"] as? Bool ?? true
        }
        // Presets follow the current implementation; preserve fully manual settings.
        if profile != 2 { applyProfile(profile) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.refresh() }
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-sharing") {
            timer?.invalidate()
            var tick = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                tick += 1
                self?.telemetry.update(["frames": tick * 960, "captureChunk": 20.0, "queue": Double(tick % 20)])
            }
        }
#endif
    }

    func applyProfile(_ value: Int) {
        profile = value
        guard value != 2 else { saveSettings(); return }
        presentation = value == 0 ? 45 : 250
        receiverMinimum = presentation
        receiverMaximum = presentation
        reserve = value == 0 ? 2 : 20
        packetFrames = 352
        compressed = false
        networkPriority = value == 0
        saveSettings()
    }

    func saveSettings() {
        UserDefaults.standard.set(["profile": profile, "presentation": presentation,
            "minimum": receiverMinimum, "maximum": receiverMaximum, "reserve": reserve,
            "packet": packetFrames, "compressed": compressed, "networkPriority": networkPriority], forKey: "timingSettings")
    }

    func start() {
        guard !capturing && !connecting && !connected && !stopping, let selected else { return }
        error = ""
#if canImport(ScreenCaptureKit)
        let picker = SCContentSharingPicker.shared
        guard picker.isAvailable else { error = String(localized: "Screen audio sharing is unavailable on this device."); return }
        do { try audioSession.begin() }
        catch { self.error = error.localizedDescription; return }
        connect(selected)
        if !pickerRegistered { picker.add(self); pickerRegistered = true }
        var configuration = SCContentSharingPickerConfiguration()
        configuration.showsMicrophoneControl = false
        configuration.showsCameraControl = false
        picker.defaultConfiguration = configuration
        picker.isActive = true
        // System-wide selection, never the current-application-only picker.
        picker.present()
#else
        error = String(localized: "Screen audio sharing requires a physical iPhone or iPad with iOS 27.")
#endif
    }

    private func connect(_ speaker: Speaker) {
        // Each capture output owns its connection, so a late callback cannot enter a new session.
        transport = HBTransport()
        volume = 0
        status = String(localized: "Connecting, muted")
        connecting = true
        transport.connectHost(speaker.host, port: speaker.port, name: speaker.name,
            deviceID: speaker.deviceID, sourceID: sourceID,
            presentationMs: Int(presentation), minimumMs: Int(receiverMinimum),
            maximumMs: Int(max(receiverMinimum, receiverMaximum)), reserveMs: Int(reserve),
            packetFrames: packetFrames, compressed: compressed, networkPriority: networkPriority)
    }

    func updateVolume(_ value: Double) {
        volume = value.rounded()
        if connected { transport.setVolume(Int(volume)) }
    }

    func stop() {
        guard !stopping else { return }
        stopping = true
        transport.setVolume(0)
        volume = 0
        capturing = false
        connected = false
        connecting = false
#if canImport(ScreenCaptureKit)
        let oldStream = stream
        let oldSink = captureSink
        stream = nil
        captureSink = nil
        SCContentSharingPicker.shared.isActive = false
        oldStream?.stopCapture { [oldSink] _ in _ = oldSink }
#endif
        transport.disconnect()
        audioSession.end()
        status = String(localized: "Not connected")
        stopping = false
    }

    private func refresh() {
        let latest = transport.snapshot()
        let state = (latest["state"] as? NSNumber)?.intValue ?? 0
        if state != 0 { telemetry.update(latest) }
        let isConnected = (latest["ready"] as? Bool) == true
        if connected != isConnected { connected = isConnected }
        if connected {
            if connecting { connecting = false }
            let nextStatus = capturing ? String(localized: "Sharing device audio") : String(localized: "Connected, waiting for sharing permission")
            if status != nextStatus { status = nextStatus }
        }
        if state < 0 {
            let failure = stats["error"] as? String ?? ""
            error = failure.isEmpty ? String(localized: "The speaker disconnected. Sharing has stopped.") : failure
            stop()
        }
        // Optional CLI diagnostics, containing timing/counters only; no audio or screen data.
        if ProcessInfo.processInfo.arguments.contains("--diagnostics") {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("diagnostics.json")
            var report = stats
            for (key, value) in audioSession.report { report[key] = value }
            report["currentState"] = state
            report["captureActive"] = capturing
            report["connected"] = connected
            report["sampledAt"] = Date().timeIntervalSince1970
            report["applicationState"] = UIApplication.shared.applicationState.rawValue
            report["thermalState"] = ProcessInfo.processInfo.thermalState.rawValue
            report["lowPowerMode"] = ProcessInfo.processInfo.isLowPowerModeEnabled
            // Last measurements survive a disconnect, while current state stays independently clear.
            // Diagnostics IO is not on the audio path and not on the UI thread.
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]) {
                diagnosticQueue.async { try? data.write(to: url, options: .atomic) }
            }
        }
    }

    deinit { timer?.invalidate(); transport.disconnect() }
}

#if canImport(ScreenCaptureKit)
extension BridgeModel: SCContentSharingPickerObserver, SCStreamDelegate {
    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        DispatchQueue.main.async { self.stop() }
    }

    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        DispatchQueue.main.async { self.error = error.localizedDescription; self.stop() }
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        DispatchQueue.main.async {
            guard self.connecting || self.connected, self.stream == nil else { return }
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            // Use an explicitly supported native capture rate; convert once in the sender.
            config.sampleRate = 48000
            config.channelCount = 2
            config.excludesCurrentProcessAudio = false
            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            do {
                // No video/microphone output, no encoder, no file-writing audio path.
                let sink = CaptureSink(transport: self.transport)
                try stream.addStreamOutput(sink, type: .audio, sampleHandlerQueue: self.audioQueue)
                self.captureSink = sink
                self.stream = stream
                stream.startCapture { error in
                    DispatchQueue.main.async {
                        guard self.stream === stream else { return }
                        if let error { self.error = error.localizedDescription; self.stop() }
                        else { self.capturing = true }
                    }
                }
            } catch { self.error = error.localizedDescription; self.stop() }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async {
            guard self.stream === stream else { return }
            self.error = error.localizedDescription
            self.stop()
        }
    }

}
#endif
