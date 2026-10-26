import XCTest

/// Explicit opt-in disposable fixture, separate from the persistent review accounts.
@MainActor
final class LiveSafetyUITests: XCTestCase {
    private struct Account: Decodable { let email: String; let password: String; let name: String }
    private struct Fixture: Decodable { let projectID: String; let disposable: Bool; let accounts: [Account] }
    func testReportBlockAndDeleteDisposableAccount() throws {
        guard let source = ProcessInfo.processInfo.environment["NALDAM_LIVE_SAFETY_JSON"] else {
            throw XCTSkip("Requires explicitly supplied disposable Firebase fixtures.")
        }
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(source.utf8))
        XCTAssertTrue(fixture.disposable)
        XCTAssertEqual(fixture.projectID, "naldam-dev")
        let account = fixture.accounts[0]
        XCTAssertTrue(account.email.hasPrefix("naldam-safety-"))
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        app.buttons["tab.conversations"].tap()
        XCTAssertTrue(app.buttons["auth.emailSignIn"].waitForExistence(timeout: 15))
        app.buttons["auth.emailSignIn"].tap()
        let email = app.textFields["auth.email.address"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap(); email.typeText(account.email)
        let password = app.secureTextFields["auth.email.password"]
        password.tap(); password.typeText(account.password)
        if app.buttons["입력 완료"].exists { app.buttons["입력 완료"].tap() }
        app.buttons["auth.email.submit"].tap()
        XCTAssertTrue(app.staticTexts["conversations.title"].waitForExistence(timeout: 30))
        if app.buttons["지금 안 함"].waitForExistence(timeout: 2) { app.buttons["지금 안 함"].tap() }
        let peer = app.staticTexts[fixture.accounts[1].name].firstMatch
        XCTAssertTrue(peer.waitForExistence(timeout: 20)); peer.tap()
        app.buttons["대화 관리"].tap(); app.buttons["신고하기"].tap()
        XCTAssertTrue(app.buttons["report.submit"].waitForExistence(timeout: 5))
        app.buttons["report.submit"].tap()
        XCTAssertTrue(app.buttons["report.done"].waitForExistence(timeout: 20))
        capture(app, "native-report-confirmed")
        app.buttons["report.done"].tap()
        app.terminate(); app.launch()
        app.buttons["home.profile"].tap()
        let delete = app.buttons["profile.deleteAccount"]
        for _ in 0..<6 where !delete.isHittable { app.swipeUp() }
        XCTAssertTrue(delete.isHittable); delete.tap()
        let submit = app.buttons["account.delete.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 10)); XCTAssertFalse(submit.isEnabled)
        let confirm = app.switches["account.delete.confirm"]
        confirm.tap()
        let reauth = app.secureTextFields["account.delete.password"]
        reauth.tap(); reauth.typeText("intentionally-wrong-password")
        app.swipeUp(); submit.tap()
        XCTAssertTrue(app.staticTexts["계정 정보를 확인하지 못했어요. 비밀번호 또는 Apple 계정을 확인해 주세요."].waitForExistence(timeout: 20))
        reauth.tap(); reauth.typeText(account.password)
        app.swipeUp(); submit.tap()
        XCTAssertTrue(app.buttons["account.delete.done"].waitForExistence(timeout: 60))
        capture(app, "native-account-deletion-completed")
        app.buttons["account.delete.done"].tap()
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
