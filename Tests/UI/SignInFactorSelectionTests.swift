#if os(iOS) || os(macOS)

import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct SignInFactorSelectionTests {
  private let clerk = Clerk.preview(.signedOut)

  private func signIn(
    preference: String = "password",
    identifier: String? = "user@example.com",
    factors: [SignInFirstFactor]
  ) -> SignIn {
    setTestEnvironment(clerk, ["displayConfig", "preferredSignInStrategy"], .string(preference))
    var state = try! clerk.signIn.state.encode().object()
    state["id"] = .string("sign_in_123")
    state["status"] = .string("needs_first_factor")
    state["identifier"] = identifier.map(JSONValue.string) ?? .null
    state["supportedFirstFactors"] = .array(try! factors.map { try $0.encode() })
    setTestResourceState(clerk.signIn, encoded: .object(state), path: [], value: .object(state))
    return clerk.signIn
  }

  @Test
  func startingFirstFactorUsesPreferenceOverPreparedVerificationStrategy() throws {
    let signIn = signIn(factors: [
      .case5(.init()), .case1(.init(emailAddressId: "ema_123", safeIdentifier: "user@example.com")),
    ])
    try setTestResourceState(signIn.firstFactorVerification,
                             encoded: signIn.firstFactorVerification.state.encode(), path: ["strategy"], value: .string("email_code"))
    #expect(signIn.startingFirstFactor?.strategy == .password)
  }

  @Test
  func startingFirstFactorDoesNotMatchMissingIdentifierToMissingSafeIdentifier() {
    let signIn = signIn(preference: "otp", identifier: nil, factors: [
      .case5(.init()), .case1(.init(emailAddressId: "ema_123", safeIdentifier: "user@example.com")),
    ])
    #expect(signIn.startingFirstFactor?.strategy == .emailCode)
  }

  @Test
  func startingFirstFactorPrefersPasswordWhenPasswordIsPreferred() {
    let signIn = signIn(factors: [
      .case5(.init()), .case1(.init(emailAddressId: "ema_123", safeIdentifier: "user@example.com")),
      .case2(.init(emailAddressId: "ema_123", safeIdentifier: "user@example.com")),
    ])
    #expect(signIn.startingFirstFactor?.strategy == .password)
  }

  @Test
  func startingFirstFactorChoosesMatchingEmailLinkWhenPasswordIsPreferredAndPasswordIsUnavailable() {
    let signIn = signIn(factors: [
      .case2(.init(emailAddressId: "ema_other", safeIdentifier: "other@example.com")),
      .case1(.init(emailAddressId: "ema_123", safeIdentifier: "user@example.com")),
      .case2(.init(emailAddressId: "ema_123", safeIdentifier: "user@example.com")),
    ])
    #expect(signIn.startingFirstFactor?.strategy == .emailLink)
    #expect(signIn.startingFirstFactor?.emailAddressId == "ema_123")
  }

  @Test
  func startingFirstFactorDoesNotForceEmailLinkForNonEmailIdentifier() {
    let signIn = signIn(preference: "otp", identifier: "username_123", factors: [
      .case6(.init()), .case2(.init(emailAddressId: "ema_123", safeIdentifier: "user@example.com")),
    ])
    #expect(signIn.startingFirstFactor?.strategy == .passkey)
  }

  @Test
  func startingFirstFactorDoesNotUseUnrelatedEmailLinkForUsernameSignIn() {
    let signIn = signIn(identifier: "username_123", factors: [
      .case2(.init(emailAddressId: "ema_123", safeIdentifier: "user@example.com")), .case5(.init()),
    ])
    #expect(signIn.startingFirstFactor?.strategy == .password)
  }

  @Test
  func resetPasswordFactorPrefersMatchingEmailCodeFactor() {
    let signIn = signIn(factors: [
      .case9(.init(phoneNumberId: "phone_123", safeIdentifier: "+15555550100")),
      .case10(.init(emailAddressId: "email_other", safeIdentifier: "other@example.com")),
      .case10(.init(emailAddressId: "email_123", safeIdentifier: "user@example.com")),
    ])
    #expect(signIn.resetPasswordFactor?.strategy == .resetPasswordEmailCode)
    #expect(signIn.resetPasswordFactor?.emailAddressId == "email_123")
  }

  @Test
  func alternativeFirstFactorsKeepEmailCodeAndFilterResetPasswordFactors() {
    let signIn = signIn(factors: [
      .case5(.init()), .case1(.init(emailAddressId: "email_123", safeIdentifier: "user@example.com")),
      .case10(.init(emailAddressId: "email_123", safeIdentifier: "user@example.com")),
    ])
    let factors = signIn.alternativeFirstFactors(currentFactor: Factor(strategy: .password))
    #expect(factors.map(\.strategy) == [.emailCode])
    #expect(factors.first?.emailAddressId == "email_123")
  }

  @Test
  func alternativeFirstFactorsKeepCodeAlternativesAndFilterNonInlineMethods() {
    let signIn = signIn(factors: [
      .case5(.init()), .case1(.init(emailAddressId: "email_123", safeIdentifier: "user@example.com")),
      .case3(.init(phoneNumberId: "phone_123", safeIdentifier: "+15555550100")),
      .case10(.init(emailAddressId: "email_123", safeIdentifier: "user@example.com")),
      .case7(.init(strategy: .oauthGoogle)), .case8(.init()),
    ])
    let strategies = signIn.alternativeFirstFactors(currentFactor: Factor(strategy: .password)).map(\.strategy)
    #expect(strategies == [.phoneCode, .emailCode] || strategies == [.emailCode, .phoneCode])
  }
}
#endif
