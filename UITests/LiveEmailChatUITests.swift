import XCTest

/// Opt-in test for the two dedicated review fixtures. Normal test runs skip it.
@MainActor
final class LiveEmailChatUITests: XCTestCase {
    private struct Account: Decodable { let email: String; let password: String; let name: String }
    private struct Credentials: Decodable { let projectID: String; let accounts: [Account] }
    private var app = XCUIApplication()

    func testTwoRealAccountsExchangeMessagesAndRestoreConversation() throws {
        guard let source = ProcessInfo.processInfo.environment["NALDAM_LIVE_EMAIL_ACCOUNTS_JSON"] else {
            throw XCTSkip("Live Firebase verification requires explicitly supplied review accounts.")
        }
        let credentials = try JSONDecoder().decode(Credentials.self, from: Data(source.utf8))
        XCTAssertEqual(credentials.projectID, "naldam-dev")
        XCTAssertEqual(credentials.accounts.count, 2)
        continueAfterFailure = false
        // No fixture, authentication bypass, or offline UI-test flag is passed to the app.
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        let firstMessage = "앱에서 보낸 인사 \(UUID().uuidString.prefix(8))"
        let reply = "앱에서 받은 답장 \(UUID().uuidString.prefix(8))"
        signIn(credentials.accounts[0])
        openChat(with: credentials.accounts[1].name)
        send(firstMessage)
        capture("live-email-account-a-sent")
        signOut()
        signIn(credentials.accounts[1])
        openChat(with: credentials.accounts[0].name)
        XCTAssertTrue(app.staticTexts[firstMessage].waitForExistence(timeout: 20))
        send(reply)
        capture("live-email-account-b-received-and-replied")
        signOut()
        signIn(credentials.accounts[0])
        openChat(with: credentials.accounts[1].name)
        XCTAssertTrue(app.staticTexts[reply].waitForExistence(timeout: 20))
        capture("live-email-account-a-restored-reply")
        signOut()
    }

    private func signIn(_ account: Account) {
        XCTAssertTrue(app.buttons["tab.conversations"].waitForExistence(timeout: 15))
        app.buttons["tab.conversations"].tap()
        XCTAssertTrue(app.buttons["auth.emailSignIn"].waitForExistence(timeout: 15))
        app.buttons["auth.emailSignIn"].tap()
        let email = app.textFields["auth.email.address"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap(); email.typeText(account.email)
        XCTAssertEqual(email.value as? String, account.email)
        let password = app.secureTextFields["auth.email.password"]
        password.tap(); password.typeText(account.password)
        if app.buttons["입력 완료"].exists { app.buttons["입력 완료"].tap() }
        app.buttons["auth.email.submit"].tap()
        XCTAssertTrue(app.staticTexts["conversations.title"].waitForExistence(timeout: 30))
    }

    private func openChat(with name: String) {
        let row = app.staticTexts[name].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        XCTAssertTrue(app.textViews["대화 메시지"].waitForExistence(timeout: 5)
                      || app.textFields["대화 메시지"].waitForExistence(timeout: 5))
    }

    private func send(_ body: String) {
        let field = app.textViews["대화 메시지"].exists ? app.textViews["대화 메시지"] : app.textFields["대화 메시지"]
        field.tap(); field.typeText(body)
        app.buttons["메시지 보내기"].tap()
        XCTAssertTrue(app.staticTexts[body].waitForExistence(timeout: 15))
        app.swipeDown()
    }

    private func signOut() {
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["home.profile"].waitForExistence(timeout: 15))
        app.buttons["home.profile"].tap()
        let button = app.buttons["profile.signOut"]
        for _ in 0..<5 where !button.isHittable { app.swipeUp() }
        XCTAssertTrue(button.isHittable)
        button.tap()
        let confirmation = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "로그아웃", "profile.signOut")).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
        app.buttons["취소"].tap()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
