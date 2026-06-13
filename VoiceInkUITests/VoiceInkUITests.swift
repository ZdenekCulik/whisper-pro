//
//  VoiceInkUITests.swift
//  VoiceInkUITests
//
//  Created by Prakash Joshi on 15/10/2024.
//

import XCTest

final class VoiceInkUITests: XCTestCase {
    private let appDefaults = UserDefaults(suiteName: "com.prakashjoshipax.VoiceInk")

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testDashboardVariantButtonsSwitchSelection() throws {
        appDefaults?.set(1, forKey: "dashboardHeroVariant")
        appDefaults?.set(true, forKey: "hasCompletedOnboardingV2")
        appDefaults?.set(false, forKey: "enableAnnouncements")
        appDefaults?.synchronize()

        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboardingV2", "YES",
            "-dashboardHeroVariant", "1",
            "-enableAnnouncements", "NO"
        ]
        app.launch()

        let v1Button = app.buttons["dashboard-variant-v1"]
        XCTAssertTrue(v1Button.waitForExistence(timeout: 10))
        waitForStoredVariant(1)

        let variantsToClick = [2, 3, 8]
        for variant in variantsToClick {
            let button = app.buttons["dashboard-variant-v\(variant)"]
            XCTAssertTrue(button.waitForExistence(timeout: 2))
            button.click()
            waitForStoredVariant(variant)
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    private func waitForStoredVariant(
        _ expectedVariant: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            appDefaults?.synchronize()
            if appDefaults?.integer(forKey: "dashboardHeroVariant") == expectedVariant {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail("Expected dashboardHeroVariant to be \(expectedVariant)", file: file, line: line)
    }
}
