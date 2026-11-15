// SPDX-License-Identifier: Apache-2.0
import XCTest

final class StoreScreenshots: XCTestCase {
    func testDiagnosticsScrollWithLiveUpdates() {
        let app=XCUIApplication()
        app.launchArguments=["-AppleLanguages","(en)","--layout-tab","diagnostics","--simulate-sharing"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Diagnostics"].waitForExistence(timeout:15))
        let footer=app.staticTexts["diagnostics-footer"]
        for _ in 0..<8 {
            if footer.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(footer.isHittable,"Live diagnostics can scroll to the last row")
        let reset=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in !footer.isHittable },object:nil)
        reset.isInverted=true
        XCTAssertEqual(XCTWaiter.wait(for:[reset],timeout:3),.completed,"Metric updates preserve scroll position")
        app.terminate()
    }
    func testStorePages() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        for locale in ["ja", "en-US"] {
            for (index, page) in ["share", "latency", "diagnostics"].enumerated() {
                let app = XCUIApplication()
                app.launchArguments = ["-AppleLanguages", locale == "ja" ? "(ja)" : "(en)",
                    "-AppleLocale", locale, "--layout-tab", page]
                app.launch()
                XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
                let expected = page == "share" ? "SpeakerHop" : page == "latency"
                    ? (locale == "ja" ? "遅延設定" : "Latency") : (locale == "ja" ? "診断" : "Diagnostics")
                XCTAssertTrue(app.navigationBars[expected].waitForExistence(timeout: 15))
                XCTAssertTrue(app.navigationBars[expected].isHittable)
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "store_\(locale)_\(index+1)_\(page)"
                shot.lifetime = .keepAlways
                add(shot)
                app.terminate()
            }
        }
    }
}
