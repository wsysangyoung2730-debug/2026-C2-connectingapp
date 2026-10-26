import XCTest

@MainActor
final class LiveChatUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-naldam-ui-testing"]
        app.launch()
    }

    func testSocialTabsRequireConnectionAndHomeRemainsAvailable() {
        XCTAssertTrue(app.buttons["home.today"].waitForExistence(timeout: 10))
        app.buttons["tab.discover"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "auth.configurationRequired").firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["discover.greet"].exists)
        XCTAssertFalse(app.buttons["받은 요청 체험하기"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Apple-login-configuration-gate"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["tab.conversations"].tap()
        XCTAssertTrue(app.staticTexts["작은 인사로 시작하는 사이"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["샘플 요청 추가"].exists)
        app.buttons["tab.home"].tap()
        XCTAssertTrue(app.buttons["home.today"].waitForExistence(timeout: 5))
        app.buttons["home.today"].tap()
        XCTAssertTrue(app.textViews["journal.answer"].waitForExistence(timeout: 5))
    }

    func testProfileExplainsLocalAndSharedData() {
        XCTAssertTrue(app.buttons["home.profile"].waitForExistence(timeout: 10))
        app.buttons["home.profile"].tap()
        XCTAssertTrue(app.textFields["profile.name"].waitForExistence(timeout: 5))
        let account = app.buttons["profile.account"]
        for _ in 0..<5 where !account.isHittable { app.swipeUp() }
        XCTAssertTrue(account.isHittable)
        account.tap()
        XCTAssertTrue(app.staticTexts["작은 인사로 시작하는 사이"].waitForExistence(timeout: 5))
    }
}
