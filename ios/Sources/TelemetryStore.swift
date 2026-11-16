// SPDX-License-Identifier: Apache-2.0
import Foundation
import Combine

final class TelemetryStore: ObservableObject {
    @Published private(set) var values: [String: Any] = [:]
    private(set) var latest: [String: Any] = [:]
    private var displays = 0

    // Transport state remains current without invalidating an offscreen Form.
    // Count visible windows so hiding one iPad window does not freeze another.
    func update(_ next: [String: Any]) {
        latest = next
        if displays > 0 { values = next }
    }
    func beginDisplay() {
        displays += 1
        if displays == 1 { values = latest }
    }
    func endDisplay() { displays = max(0, displays - 1) }
}
