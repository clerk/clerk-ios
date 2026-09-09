#if os(iOS) || os(macOS)
import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor struct SignUpEmailVerificationStrategyTests {
  private let clerk = Clerk.preview(.signedOut)

  private func setStrategy(_ strategy: String?) {
    let verification = clerk.signUp.verifications.emailAddress
    setTestResourceState(verification, encoded: try! verification.state.encode(),
                         path: ["strategy"], value: strategy.map(JSONValue.string) ?? .null)
  }

  @Test func returnsEmailLinkWhenVerificationHasEmailLinkStrategy() {
    setStrategy("email_link")
    #expect(clerk.signUp.emailVerificationStrategy == .emailLink)
  }

  @Test func returnsEmailCodeWhenVerificationHasEmailCodeStrategy() {
    setStrategy("email_code")
    #expect(clerk.signUp.emailVerificationStrategy == .emailCode)
  }

  @Test func returnsEmailLinkWhenEnvironmentHasEmailLinkVerification() {
    setStrategy(nil)
    setTestEnvironment(clerk, ["userSettings", "attributes", "email_address", "verifications"], .array([.string("email_link")]))
    #expect(clerk.signUp.emailVerificationStrategy == .emailLink)
  }

  @Test func defaultsToEmailCodeWhenNoVerificationInfo() {
    setStrategy(nil)
    setTestEnvironment(clerk, ["userSettings", "attributes", "email_address", "verifications"], .array([]))
    #expect(clerk.signUp.emailVerificationStrategy == .emailCode)
  }
}
#endif
