import XCTest

@MainActor
final class AuthJourneyTests: XCTestCase {
  func testEmailCodeErrorRetryAndPrebuiltFinalization() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launch()
    defer { app.terminate() }

    let identifier = app.descendants(matching: .any).matching(identifier: "clerk.auth.start.identifier").firstMatch
    XCTAssertTrue(identifier.waitForExistence(timeout: 20), app.debugDescription)
    identifier.tap()
    app.typeText("test@example.com")
    capture("01-identifier", app: app)
    app.buttons["clerk.auth.start.continue"].tap()

    let code = app.textFields["clerk.auth.signIn.code"]
    XCTAssertTrue(code.waitForExistence(timeout: 15), app.debugDescription)
    assertState("session=none; user=none; completions=0; touches=0; codes=", app: app)
    code.tap()
    code.typeText("000000")
    XCTAssertTrue(app.staticTexts["That code is incorrect. Try again."].waitForExistence(timeout: 15), app.debugDescription)
    assertState("session=none; user=none; completions=0; touches=0; codes=000000", app: app)
    capture("02-invalid-code", app: app)
    app.buttons["Close"].tap()
    XCTAssertTrue(app.buttons["Close"].waitForNonExistence(timeout: 5))

    code.tap()
    code.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "424242")
    XCTAssertTrue(app.staticTexts["journey.completed"].waitForExistence(timeout: 15), app.debugDescription)
    assertState("session=active; user=user_native; completions=1; touches=1; codes=000000,424242", app: app)
    capture("03-completed", app: app)
  }

  private func assertState(_ expected: String, app: XCUIApplication) {
    let state = app.staticTexts["journey.state"]
    let predicate = NSPredicate(format: "label == %@", expected)
    let wait = XCTNSPredicateExpectation(predicate: predicate, object: state)
    XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 5), .completed, state.label)
  }

  private func capture(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
