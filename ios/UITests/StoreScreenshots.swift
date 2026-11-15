// SPDX-License-Identifier: Apache-2.0
import XCTest

final class StoreScreenshots: XCTestCase {
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
