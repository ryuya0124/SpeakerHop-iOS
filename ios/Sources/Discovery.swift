// SPDX-License-Identifier: Apache-2.0
import Foundation
import Darwin

struct Speaker: Identifiable, Equatable {
    let id: String
    let name: String
    let host: String
    let port: Int
    let deviceID: String
}

final class Discovery: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published var speakers: [Speaker] = []
    @Published var message = ""
    @Published var searching = false
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []

    override init() {
        super.init()
        browser.delegate = self
    }

    func start() {
        browser.stop()
        services.forEach { $0.stop() }
        services.removeAll()
        speakers.removeAll()
        searching = true
        message = ""
        browser.searchForServices(ofType: "_raop._tcp.", inDomain: "local.")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeAll { $0 == service }
        speakers.removeAll { $0.id == service.name }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        searching = false
        message = String(localized: "Local network discovery is unavailable. Allow Local Network access in Settings.")
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        let txt = sender.txtRecordData().map(NetService.dictionary(fromTXTRecord:)) ?? [:]
        func value(_ key: String) -> String { txt[key].flatMap { String(data: $0, encoding: .utf8) } ?? "" }
        let model = value("am").lowercased()
        guard model.hasPrefix("audioaccessory") || model.contains("homepod"),
            value("pw").lowercased() != "true" else { return }
        let deviceID = value("deviceid").isEmpty ? String(sender.name.split(separator: "@").first ?? "") : value("deviceid")
        guard !deviceID.isEmpty else { return }
        for address in sender.addresses ?? [] {
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = address.withUnsafeBytes { raw -> Int32 in
                guard let ptr = raw.baseAddress?.assumingMemoryBound(to: sockaddr.self), ptr.pointee.sa_family == sa_family_t(AF_INET) else { return -1 }
                return getnameinfo(ptr, socklen_t(address.count), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            }
            if result == 0 {
                let speaker = Speaker(id: sender.name,
                    name: String(sender.name.split(separator: "@", maxSplits: 1).last ?? Substring(sender.name)),
                    host: String(cString: host), port: sender.port, deviceID: deviceID)
                speakers.removeAll { $0.id == speaker.id }
                speakers.append(speaker)
                speakers.sort { $0.name < $1.name }
                return
            }
        }
    }
}
