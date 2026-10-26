import XCTest

/// Captures the production views with fictional, in-memory data. This does not
/// exercise Apple authentication or the live Firebase service.
@MainActor
final class AppStoreScreenshotTests: XCTestCase {
    func testCaptureStoreScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-naldam-ui-testing", "-naldam-seeded-ui", "-naldam-store-screenshot"]
        app.launch()
        XCTAssertTrue(app.buttons["home.today"].waitForExistence(timeout: 15))
        capture("store-01-home", app)
        app.buttons["interests.handle"].tap()
        XCTAssertTrue(app.buttons["interests.edit"].waitForExistence(timeout: 5))
        capture("store-02-envelope", app)
        app.buttons["interests.edit"].tap()
        XCTAssertTrue(app.textFields["interests.search"].waitForExistence(timeout: 5))
        capture("store-03-interests", app)
        app.buttons["interests.save"].tap()
        app.buttons["home.today"].tap()
        XCTAssertTrue(app.textViews["journal.answer"].waitForExistence(timeout: 5))
        capture("store-04-journal", app)
        app.buttons["뒤로"].tap()
        app.buttons["tab.discover"].tap()
        XCTAssertTrue(app.buttons["discover.greet"].waitForExistence(timeout: 10))
        capture("store-05-discover", app)
        app.buttons["tab.conversations"].tap()
        XCTAssertTrue(app.staticTexts["conversations.title"].waitForExistence(timeout: 5))
        capture("store-06-conversations", app)
        let conversation = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "산책길에서 만난 작은 풍경")).firstMatch
        XCTAssertTrue(conversation.waitForExistence(timeout: 5))
        conversation.tap()
        XCTAssertTrue(app.buttons["대화 관리"].waitForExistence(timeout: 5))
        capture("store-07-chat", app)
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
