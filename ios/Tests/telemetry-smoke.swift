// SPDX-License-Identifier: Apache-2.0
import Foundation
import Combine

@main
struct TelemetrySmoke {
    static func main() {
        let store = TelemetryStore()
        var publications = 0
        let token = store.$values.dropFirst().sink { _ in publications += 1 }
        for frame in 0..<1000 { store.update(["frames": frame]) }
        precondition(publications == 0, "Hidden diagnostics must not invalidate the UI")
        precondition(store.latest["frames"] as? Int == 999, "Transport state must stay current while hidden")
        store.beginDisplay()
        precondition(store.values["frames"] as? Int == 999, "Opening diagnostics must catch up immediately")
        store.beginDisplay()
        store.endDisplay()
        store.update(["frames": 1000])
        precondition(publications == 2 && store.values["frames"] as? Int == 1000,
            "Closing one window must not freeze another visible diagnostics window")
        store.endDisplay()
        store.update(["frames": 1001])
        precondition(publications == 2, "Closing the last diagnostics window must stop UI publications")
        store.beginDisplay()
        precondition(publications == 3 && store.values["frames"] as? Int == 1001,
            "Reopening diagnostics must show the latest retained measurement")
        withExtendedLifetime(token) {}
        print("PASS: 1000 hidden updates produced 0 UI publications; catch-up and multiple windows stay live")
    }
}
