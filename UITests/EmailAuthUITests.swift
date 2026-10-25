import XCTest

@MainActor
final class EmailAuthUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-naldam-ui-testing", "-email-auth-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.discover"].waitForExistence(timeout: 10))
        app.buttons["tab.discover"].tap()
        XCTAssertTrue(app.buttons["auth.emailSignIn"].waitForExistence(timeout: 5))
        app.buttons["auth.emailSignIn"].tap()
        XCTAssertTrue(app.textFields["auth.email.address"].waitForExistence(timeout: 5))
    }

    func testModesClearPasswordsAndResetNeedsOnlyEmail() {
        let email = app.textFields["auth.email.address"]
        email.tap()
        email.typeText("form-test@example.invalid")
        let password = app.secureTextFields["auth.email.password"]
        password.tap()
        password.typeText(UUID().uuidString)
        hideKeyboard()
        app.buttons["auth.email.createAccount"].tap()
        XCTAssertTrue(app.secureTextFields["auth.email.confirmPassword"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["auth.email.submit"].isEnabled)
        XCTAssertEqual(email.value as? String, "form-test@example.invalid")
        app.buttons["auth.email.backToSignIn"].tap()
        app.buttons["auth.email.forgotPassword"].tap()
        XCTAssertFalse(app.secureTextFields["auth.email.password"].exists)
        XCTAssertTrue(app.buttons["auth.email.submit"].isEnabled)
        // UI tests must never contact Firebase, even for a syntactically valid reset request.
        app.buttons["auth.email.submit"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "아직 계정 연결을 준비 중")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["auth.email.resetConfirmation"].exists)
    }

    func testSignUpRejectsMismatchedPasswordsBeforeNetwork() {
        app.buttons["auth.email.createAccount"].tap()
        let email = app.textFields["auth.email.address"]
        email.tap()
        email.typeText("form-test@example.invalid")
        let password = app.secureTextFields["auth.email.password"]
        password.tap()
        password.typeText(UUID().uuidString)
        hideKeyboard()
        let confirmation = app.secureTextFields["auth.email.confirmPassword"]
        confirmation.tap()
        confirmation.typeText(UUID().uuidString)
        hideKeyboard()
        app.buttons["auth.email.submit"].tap()
        XCTAssertTrue(app.staticTexts["두 비밀번호가 같지 않아요. 다시 확인해 주세요."].waitForExistence(timeout: 5))
        hideKeyboard()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "email-signup-validation"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func hideKeyboard() {
        let done = app.buttons["입력 완료"]
        if done.exists { done.tap() }
    }
}
