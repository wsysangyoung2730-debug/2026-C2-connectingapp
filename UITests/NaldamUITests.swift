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
        XCTAssertFalse(app.buttons["tab.home"].exists)
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
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["오늘 담은 기록"].exists)
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
        XCTAssertTrue(app.buttons["tab.home"].exists)
        capture("02-envelope-middle")
        app.buttons["interests.edit"].tap()
        let search = app.textFields["interests.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.home"].waitForNonExistence(timeout: 5))
        capture("03-envelope-expanded")
        search.tap()
        search.typeText("독서\n")
        let add = app.buttons["독서, 선택하기"]
        reveal(add)
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        app.buttons["interests.save"].tap()
        XCTAssertTrue(app.buttons["독서, 관심사 펼치기"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
    }

    func testDiscoveryAndSampleChat() {
        app.buttons["tab.discover"].tap()
        XCTAssertTrue(app.staticTexts["discover.title"].waitForExistence(timeout: 5))
        capture("06-discover")
        app.buttons["tab.conversations"].tap()
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

    func testSixDistinctSlotsAndCustomInterestLength() {
        app.terminate()
        app.launchArguments = ["-naldam-ui-testing", "-naldam-seeded-ui"]
        app.launch()
        XCTAssertTrue(app.buttons["interests.handle"].waitForExistence(timeout: 10))
        app.buttons["interests.handle"].tap()
        app.buttons["interests.edit"].tap()
        let slots = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "interests.slot."))
        XCTAssertEqual(slots.count, 6)
        XCTAssertEqual(Set(slots.allElementsBoundByIndex.map(\.label)).count, 6)
        XCTAssertTrue(app.buttons["profile.photo"].exists)
        capture("18-interests-six-selected")
        app.buttons["interests.slot.0"].tap()
        let search = app.textFields["interests.search"]
        search.tap(); search.typeText("abcdef\n")
        let add = app.buttons["interests.addCustom"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertFalse(add.isEnabled)
        app.buttons["검색어 지우기"].tap()
        search.tap(); search.typeText("knit\n")
        XCTAssertTrue(add.isEnabled)
        add.tap()
        XCTAssertTrue(app.buttons["knit 삭제"].waitForExistence(timeout: 5))
        app.buttons["interests.save"].tap()
        XCTAssertTrue(app.buttons["knit, 관심사 펼치기"].waitForExistence(timeout: 5))
        capture("11-six-unique-interests")
    }

    func testRecentFiveEntriesAndDirectRecordNavigation() {
        app.terminate()
        app.launchArguments = ["-naldam-ui-testing", "-naldam-seeded-ui"]
        app.launch()
        XCTAssertTrue(app.buttons["home.recent.0"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["home.recent.5"].exists)
        let last = app.buttons["home.recent.4"]
        for _ in 0..<8 {
            let handle = app.buttons["interests.handle"]
            if last.exists && last.frame.maxY < handle.frame.minY { break }
            let scroll = app.scrollViews["home.scroll"]
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
                .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
        }
        XCTAssertTrue(last.isHittable)
        capture("12-five-recent-records")
        last.tap()
        XCTAssertTrue(app.textViews["journal.answer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["journal.answer"].value as? String == "서두르지 않기로 한 하루.")
    }

    func testUnreadFilterAndQuestionDraft() {
        app.terminate()
        app.launchArguments = ["-naldam-ui-testing", "-naldam-seeded-ui"]
        app.launch()
        app.buttons["tab.discover"].tap()
        XCTAssertTrue(app.buttons["discover.greet"].waitForExistence(timeout: 5))
        capture("13-discovery-refresh")
        app.buttons["tab.conversations"].tap()
        let filter = app.segmentedControls["conversations.filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.buttons["안 읽음 1"].tap()
        capture("14-conversations-refresh")
        let minseo = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "민서")).firstMatch
        XCTAssertTrue(minseo.waitForExistence(timeout: 5))
        minseo.tap()
        XCTAssertTrue(app.buttons["tab.conversations"].waitForNonExistence(timeout: 5))
        let prompt = app.buttons["chat.prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        capture("15-chat-refresh")
        prompt.tap()
        let composer = app.textFields["이 기기에 저장할 샘플 대화 메시지"]
        XCTAssertFalse((composer.value as? String ?? "").isEmpty)
        app.buttons["메시지 기기에 저장"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["모든 이야기를 읽었어요"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
        app.buttons["tab.home"].tap()
        XCTAssertTrue(app.buttons["interests.handle"].waitForExistence(timeout: 5))
        let tabAtBottom = NSPredicate { _, _ in
            self.app.buttons["tab.home"].frame.minY > self.app.frame.height * 0.8
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: tabAtBottom, object: nil)], timeout: 5), .completed)
        capture("17-home-seeded")
    }

    func testProfilePhotoSelection() {
        app.buttons["interests.handle"].tap()
        let photo = app.buttons["profile.photo"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        photo.tap()
        let firstPhoto = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 10))
        firstPhoto.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let changed = app.buttons["내 프로필 사진 변경"]
        XCTAssertTrue(changed.waitForExistence(timeout: 10))
        capture("16-profile-photo-selected")
    }
}
