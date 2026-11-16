// SPDX-License-Identifier: Apache-2.0
import XCTest

final class StoreScreenshots: XCTestCase {
    func testLegacyLowPresetMigrationAndSelectionPersists() {
        continueAfterFailure=false
        let app=XCUIApplication()
        app.launchArguments=["-AppleLanguages","(en)","--layout-tab","latency",
            "--timing-settings-json","{\"profile\":0}"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Latency"].waitForExistence(timeout:15))
        XCTAssertTrue(app.segmentedControls.buttons["Ultra low"].isSelected)
        app.segmentedControls.buttons["Low latency"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Low latency"].isSelected)
        XCTAssertTrue(app.staticTexts["Low latency uses a 500 ms receiver target and 50 ms of input reserve."].exists)
        app.terminate()
        app.launchArguments=["-AppleLanguages","(en)","--layout-tab","latency"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Latency"].waitForExistence(timeout:15))
        XCTAssertTrue(app.segmentedControls.buttons["Low latency"].isSelected)
        app.terminate()
    }

    func testLaunchWithMaximumManualBounds() {
        continueAfterFailure=false
        let app=XCUIApplication()
        app.launchArguments=["-AppleLanguages","(en)","--timing-settings-json",
            "{\"profile\":2,\"presentation\":2000,\"minimum\":2000,\"maximum\":2000,\"reserve\":100,\"packet\":352}",
            "--layout-tab","latency"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Latency"].waitForExistence(timeout:15))
        for _ in 0..<4 {
            if app.staticTexts["Fixed at this value"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Fixed at this value"].isHittable)
        XCTAssertTrue(app.wait(for:.runningForeground,timeout:5))
        app.terminate()
    }

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
        let frames = app.staticTexts["frames-counter"]
        XCTAssertTrue(frames.isHittable)
        let previous = frames.label
        let updating = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in frames.label != previous }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [updating], timeout: 3), .completed, "Visible diagnostics stay live")
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
                    "-AppleLocale", locale, "--timing-settings-json", "{}", "--layout-tab", page]
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
