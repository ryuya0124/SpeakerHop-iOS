// SPDX-License-Identifier: Apache-2.0
import Foundation

final class TelemetryStore: ObservableObject {
    @Published private(set) var values: [String: Any] = [:]
    func update(_ next: [String: Any]) { values = next }
}
