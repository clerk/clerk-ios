#if os(iOS)

@testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct AuthFieldAccessibilityTests {
  @Test
  func emptyFieldsExposeOneTextFieldEachAndHideDecorativeText() async throws {
    let host = try await AccessibilityHost(Fields())
    defer { host.close() }
    let elements = host.elements()

    let textFields = elements.compactMap { $0 as? UITextField }
    #expect(textFields.count == 4)
    #expect(textFields.filter(\.isSecureTextEntry).count == 1)

    let otherLabels = host.labelsOfNonTextFieldElements()
    #expect(otherLabels.count == 2)
    #expect(otherLabels.contains("Show password"))
    #expect(otherLabels.contains { $0.contains("+") })
    #expect(!otherLabels.contains("Email address"))
    #expect(!otherLabels.contains("Password"))
    #expect(!otherLabels.contains("Phone number"))
    #expect(!otherLabels.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty })
  }

  @Test
  func togglingThePasswordExposesOnlyTheVisibleTextField() async throws {
    let host = try await AccessibilityHost(ClerkTextField("Password", text: .constant(""), isSecure: true))
    defer { host.close() }

    let showPassword = try #require(host.element(labeled: "Show password"))
    #expect(showPassword.accessibilityActivate())
    try await host.settle()

    let textFields = host.elements().compactMap { $0 as? UITextField }
    #expect(textFields.count == 1)
    #expect(textFields.first?.isSecureTextEntry == false)
    #expect(host.labelsOfNonTextFieldElements() == ["Hide password"])

    let hidePassword = try #require(host.element(labeled: "Hide password"))
    #expect(hidePassword.accessibilityActivate())
    try await host.settle()

    let hiddenTextFields = host.elements().compactMap { $0 as? UITextField }
    #expect(hiddenTextFields.count == 1)
    #expect(hiddenTextFields.first?.isSecureTextEntry == true)
    #expect(host.labelsOfNonTextFieldElements() == ["Show password"])
  }

  private struct Fields: View {
    @State private var email = ""
    @State private var password = ""
    @State private var phoneNumber = ""
    @State private var code = ""
    @State private var codeFieldState = OTPField.FieldState.default
    @FocusState private var codeIsFocused: Bool

    var body: some View {
      VStack {
        ClerkTextField("Email address", text: $email)
        ClerkTextField("Password", text: $password, isSecure: true)
        ClerkPhoneNumberField("Phone number", text: $phoneNumber)
        OTPField(code: $code, fieldState: $codeFieldState, isFocused: $codeIsFocused) { _ in .stop }
      }
    }
  }
}

@MainActor
private final class AccessibilityHost {
  private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
  private let controller: UIViewController

  init(_ view: some View) async throws {
    // SwiftUI only builds its accessibility tree while an assistive technology is active.
    // UI automation enables it through this libAccessibility function; there is no public API.
    let library = try #require(dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW))
    let setAutomationEnabled = try #require(dlsym(library, "_AXSSetAutomationEnabled"))
    typealias SetAutomationEnabled = @convention(c) (Int32) -> Void
    unsafeBitCast(setAutomationEnabled, to: SetAutomationEnabled.self)(1)

    controller = UIHostingController(rootView: view)
    window.rootViewController = controller
    window.makeKeyAndVisible()
    try await settle()
  }

  func settle() async throws {
    for _ in 0 ..< 30 {
      try await Task.sleep(for: .milliseconds(50))
      controller.view.layoutIfNeeded()
    }
  }

  func elements() -> [Any] {
    controller.view.accessibilityElements ?? []
  }

  func element(labeled label: String) -> NSObject? {
    elements()
      .compactMap { $0 as? NSObject }
      .first { $0.accessibilityLabel == label }
  }

  func labelsOfNonTextFieldElements() -> [String] {
    elements()
      .filter { !($0 is UITextField) }
      .compactMap { ($0 as? NSObject)?.accessibilityLabel }
  }

  func close() {
    window.isHidden = true
  }
}

#endif
