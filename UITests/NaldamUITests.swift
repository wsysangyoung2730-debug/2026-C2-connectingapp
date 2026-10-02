import XCTest

@MainActor
final class NaldamUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-naldam-ui-testing"]
        app.launch()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
    }

    func testHomeJournalSaveAndHistory() {
        XCTAssertTrue(app.buttons["home.today"].waitForExistence(timeout: 10))
        capture("01-home")
        app.buttons["home.today"].tap()
        let answer = app.textViews["journal.answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        answer.tap()
        answer.typeText("Today I found a quiet moment during a walk.")
        if app.buttons["완료"].exists { app.buttons["완료"].tap() }
        let save = app.buttons["journal.save"]
        reveal(save)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["기록을 저장했어요"].waitForExistence(timeout: 5))
        capture("04-journal")
        app.buttons["뒤로"].tap()
        XCTAssertTrue(app.buttons["home.today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["오늘도 나를\n한 장 담았어요."].exists)
        let history = app.buttons["home.history"]
        for _ in 0..<5 {
            let handleY = app.buttons["interests.handle"].frame.minY
            if history.exists && history.frame.maxY < handleY { break }
            let scroll = app.scrollViews["home.scroll"]
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
                .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)))
        }
        history.tap()
        XCTAssertTrue(app.navigationBars["나의 기록"].waitForExistence(timeout: 5))
        capture("05-history")
    }

    func testEnvelopeThreeStatesAndInterestSave() {
        let handle = app.buttons["interests.handle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 10))
        handle.tap()
        XCTAssertTrue(app.buttons["interests.edit"].waitForExistence(timeout: 5))
        capture("02-envelope-middle")
        app.buttons["interests.edit"].tap()
        let search = app.textFields["interests.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        capture("03-envelope-expanded")
        search.tap()
        search.typeText("독서\n")
        let add = app.buttons["독서, 선택하기"]
        reveal(add)
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        app.buttons["interests.save"].tap()
        XCTAssertTrue(app.buttons["독서, 관심사 펼치기"].waitForExistence(timeout: 5))
    }

    func testDiscoveryAndSampleChat() {
        app.tabBars.buttons["발견"].tap()
        XCTAssertTrue(app.navigationBars["발견"].waitForExistence(timeout: 5))
        capture("06-discover")
        app.tabBars.buttons["대화"].tap()
        let demo = app.buttons["받은 요청 체험하기"]
        reveal(demo)
        demo.tap()
        app.buttons["샘플 요청 추가"].tap()
        capture("07-conversations")
        let requests = app.buttons["요청 모두 보기"]
        reveal(requests)
        requests.tap()
        let firstRequest = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "민서")).firstMatch
        XCTAssertTrue(firstRequest.waitForExistence(timeout: 5))
        firstRequest.tap()
        let accept = app.buttons["샘플 요청 수락"]
        reveal(accept)
        accept.tap()
        app.buttons["대화 열기"].tap()
        let composer = app.textFields["이 기기에 저장할 샘플 대화 메시지"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Hello from the local sample.")
        app.buttons["메시지 기기에 저장"].tap()
        XCTAssertTrue(app.staticTexts["Hello from the local sample."].waitForExistence(timeout: 5))
        capture("08-chat")
    }

    func testOnboardingAndLargeTextProfile() {
        app.terminate()
        app.launchArguments = ["-naldam-ui-testing", "-naldam-show-onboarding",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 10))
        app.buttons["건너뛰기"].tap()
        app.buttons["onboarding.next"].tap()
        XCTAssertTrue(app.buttons["home.profile"].waitForExistence(timeout: 5))
        capture("09-home-large-text")
        app.buttons["home.profile"].tap()
        XCTAssertTrue(app.textFields["profile.name"].waitForExistence(timeout: 5))
        app.buttons["취소"].tap()
        app.buttons["interests.handle"].tap()
        app.buttons["interests.handle"].tap()
        XCTAssertTrue(app.buttons["interests.save"].waitForExistence(timeout: 5))
        capture("10-interests-large-text")
    }
}
