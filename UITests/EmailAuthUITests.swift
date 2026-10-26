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
        password.typeText("form-validation-password-A9!")
        hideKeyboard()
        app.buttons["auth.email.createAccount"].tap()
        XCTAssertTrue(app.secureTextFields["auth.email.password"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.secureTextFields["auth.email.confirmPassword"].exists)
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
        password.typeText("form-validation-password-A9!")
        hideKeyboard()
        app.buttons["auth.email.submit"].tap()
        // The OS may offer to save this fake test password between form steps.
        if app.buttons["지금 안 함"].waitForExistence(timeout: 2) { app.buttons["지금 안 함"].tap() }
        XCTAssertTrue(app.secureTextFields["auth.email.confirmPassword"].waitForExistence(timeout: 5), "Full password validation: \(app.descendants(matching: .any)["auth.email.error"].firstMatch.label)")
        let confirmation = app.secureTextFields["auth.email.confirmPassword"]
        confirmation.tap()
        confirmation.typeText("form-validation-password-B9!")
        hideKeyboard()
        app.buttons["auth.email.submit"].tap()
        hideKeyboard()
        let validation = app.descendants(matching: .any)["auth.email.error"].firstMatch
        XCTAssertTrue(validation.waitForExistence(timeout: 5))
        XCTAssertTrue(validation.label.contains("두 비밀번호가 같지 않아요"), "Validation: \(validation.label)")
        hideKeyboard()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "email-signup-validation"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testValidSignUpCanRetryAfterUnavailableConnection() {
        app.buttons["auth.email.createAccount"].tap()
        let email = app.textFields["auth.email.address"]
        email.tap(); email.typeText("form-test@example.invalid")
        let password = app.secureTextFields["auth.email.password"]
        password.tap(); password.typeText("form-validation-password-A9!")
        hideKeyboard()
        app.buttons["auth.email.submit"].tap()
        if app.buttons["지금 안 함"].waitForExistence(timeout: 2) { app.buttons["지금 안 함"].tap() }
        let confirmation = app.secureTextFields["auth.email.confirmPassword"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap(); confirmation.typeText("form-validation-password-A9!")
        hideKeyboard()
        app.buttons["auth.email.submit"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "아직 계정 연결을 준비 중")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["auth.email.password"].exists)
        XCTAssertFalse(app.secureTextFields["auth.email.confirmPassword"].exists)
        XCTAssertFalse(app.buttons["auth.email.submit"].isEnabled)
        XCTAssertEqual(email.value as? String, "form-test@example.invalid")
    }

    private func hideKeyboard() {
        let done = app.buttons["입력 완료"]
        if done.exists { done.tap() }
    }
}
