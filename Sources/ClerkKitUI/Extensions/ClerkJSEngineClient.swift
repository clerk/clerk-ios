#if os(iOS) || os(macOS)

import ClerkJSCore
import ClerkKit
import Foundation

@MainActor
final class ClerkJSEngineClient: ClerkEngineClient {
  private let engine: ClerkJSCore.Clerk
  private let kit: ClerkKit.Clerk

  init(engine: ClerkJSCore.Clerk, kit: ClerkKit.Clerk) {
    self.engine = engine
    self.kit = kit
  }

  func signIn(identifier: String) async throws {
    await loadIfNeeded()
    _ = try await engine.client.signIn.create(.init(identifier: identifier))
    publish()
  }

  func signInWithEmailCode(emailAddress: String) async throws {
    await loadIfNeeded()
    _ = try await engine.client.signIn.create(
      .init(identifier: emailAddress, strategy: "email_code")
    )
    publish()
  }

  func signInWithPhoneCode(phoneNumber: String) async throws {
    await loadIfNeeded()
    _ = try await engine.client.signIn.create(
      .init(identifier: phoneNumber, strategy: "phone_code")
    )
    publish()
  }

  func signInWithPassword(identifier: String, password: String) async throws {
    await loadIfNeeded()
    let signIn = try await engine.client.signIn.create(
      .init(identifier: identifier, strategy: "password", password: password)
    )
    try await activateIfComplete(signIn)
  }

  func sendEmailCode(emailAddressId: String?) async throws {
    _ = try await engine.client.signIn.prepareFirstFactor(
      .init(strategy: .emailCode, emailAddressId: emailAddressId)
    )
    publish()
  }

  func sendPhoneCode(phoneNumberId: String?) async throws {
    _ = try await engine.client.signIn.prepareFirstFactor(
      .init(strategy: .phoneCode, phoneNumberId: phoneNumberId)
    )
    publish()
  }

  func verifyEmailCode(_ code: String) async throws {
    let signIn = try await engine.client.signIn.attemptFirstFactor(
      .init(strategy: .emailCode, code: code)
    )
    try await activateIfComplete(signIn)
  }

  func verifyPhoneCode(_ code: String) async throws {
    let signIn = try await engine.client.signIn.attemptFirstFactor(
      .init(strategy: .phoneCode, code: code)
    )
    try await activateIfComplete(signIn)
  }

  func authenticateWithPassword(_ password: String) async throws {
    let signIn = try await engine.client.signIn.attemptFirstFactor(
      .init(strategy: .password, password: password)
    )
    try await activateIfComplete(signIn)
  }

  func setActive(sessionId: String, organizationId: String?) async throws {
    await loadIfNeeded()
    try await engine.setActive(.init(session: sessionId, organization: organizationId))
    publish()
  }

  func signOut(sessionId: String?) async throws {
    await loadIfNeeded()
    if let sessionId {
      try await engine.signOut(SignOutOptions(sessionId: sessionId, redirectUrl: nil))
    } else {
      try await engine.signOut()
    }
    publish()
  }

  func getToken(template: String?, skipCache: Bool) async throws -> String? {
    await loadIfNeeded()
    return try await engine.session.getToken(
      .init(template: template, skipCache: skipCache)
    )
  }

  func signUp(
    emailAddress: String?,
    password: String?,
    firstName: String?,
    lastName: String?,
    username: String?,
    phoneNumber: String?,
    legalAccepted: Bool?,
    transfer: Bool
  ) async throws {
    await loadIfNeeded()
    let signUp = try await engine.client.signUp.create(
      .init(
        emailAddress: emailAddress,
        phoneNumber: phoneNumber,
        username: username,
        password: password,
        firstName: firstName,
        lastName: lastName,
        legalAccepted: legalAccepted,
        transfer: transfer ? true : nil
      )
    )
    try await activateIfComplete(signUp)
  }

  func sendSignUpEmailCode() async throws {
    _ = try await engine.client.signUp.prepareVerification(.init(strategy: .emailCode))
    publish()
  }

  func sendSignUpPhoneCode() async throws {
    _ = try await engine.client.signUp.prepareVerification(.init(strategy: .phoneCode))
    publish()
  }

  func verifySignUpEmailCode(_ code: String) async throws {
    let signUp = try await engine.client.signUp.attemptVerification(
      .init(strategy: .emailCode, code: code)
    )
    try await activateIfComplete(signUp)
  }

  func verifySignUpPhoneCode(_ code: String) async throws {
    let signUp = try await engine.client.signUp.attemptVerification(
      .init(strategy: .phoneCode, code: code)
    )
    try await activateIfComplete(signUp)
  }

  func authenticateWithRedirect(strategy: String, redirectUrl: String, identifier: String?) async throws {
    await loadIfNeeded()
    try await engine.client.signIn.authenticateWithRedirect(
      .init(strategy: strategy, redirectUrl: resolvedRedirectUrl(redirectUrl), identifier: identifier)
    )
    try await activateIfCompleteAfterRedirect()
  }

  func startEnterpriseSSO(emailAddress: String, redirectUrl: String) async throws {
    await loadIfNeeded()
    let resolved = resolvedRedirectUrl(redirectUrl)
    _ = try await engine.client.signIn.create(
      .init(identifier: emailAddress, strategy: "enterprise_sso", redirectUrl: resolved)
    )
    _ = try await engine.client.signIn.prepareFirstFactor(
      .init(strategy: .enterpriseSSO, redirectUrl: resolved)
    )
    publish()
  }

  func signInWithTicket(_ ticket: String) async throws {
    await loadIfNeeded()
    let signIn = try await engine.client.signIn.create(
      .init(strategy: "ticket", ticket: ticket)
    )
    try await activateIfComplete(signIn)
  }

  func signInWithIdToken(strategy: String, token: String) async throws {
    await loadIfNeeded()
    let signIn = try await engine.client.signIn.create(
      .init(strategy: strategy, token: token)
    )
    try await activateIfComplete(signIn)
  }

  func authenticateWithIdToken(strategy _: String, token: String) async throws {
    let signIn = try await engine.client.signIn.attemptFirstFactor(
      .init(strategy: .oauthTokenApple, token: token)
    )
    try await activateIfComplete(signIn)
  }

  func signUpWithTicket(_ ticket: String) async throws {
    await loadIfNeeded()
    let signUp = try await engine.client.signUp.create(
      .init(ticket: ticket, strategy: "ticket")
    )
    try await activateIfComplete(signUp)
  }

  func signUpWithIdToken(strategy: String, token: String, firstName: String?, lastName: String?) async throws {
    await loadIfNeeded()
    let signUp = try await engine.client.signUp.create(
      .init(firstName: firstName, lastName: lastName, token: token, strategy: strategy)
    )
    try await activateIfComplete(signUp)
  }

  func createPasskeySignIn() async throws {
    await loadIfNeeded()
    _ = try await engine.client.signIn.create(.init(strategy: "passkey"))
    publish()
  }

  func authenticateWithPasskey(autofill: Bool) async throws {
    await loadIfNeeded()
    let signIn = try await engine.client.signIn.authenticateWithPasskey(
      AuthenticateWithPasskeyParams(flow: autofill ? .autofill : nil)
    )
    try await activateIfComplete(signIn)
  }

  func sendMfaPhoneCode(phoneNumberId: String?) async throws {
    _ = try await engine.client.signIn.prepareSecondFactor(
      .init(strategy: .phoneCode, phoneNumberId: phoneNumberId)
    )
    publish()
  }

  func sendMfaEmailCode(emailAddressId: String?) async throws {
    _ = try await engine.client.signIn.prepareSecondFactor(
      .init(strategy: .emailCode, emailAddressId: emailAddressId)
    )
    publish()
  }

  func verifyMfaCode(_ code: String, type: ClerkKit.SignIn.MfaType) async throws {
    let signIn = try await engine.client.signIn.attemptSecondFactor(
      .init(strategy: secondFactorStrategy(type), code: code)
    )
    try await activateIfComplete(signIn)
  }

  func sendResetPasswordEmailCode(emailAddressId: String?) async throws {
    _ = try await engine.client.signIn.prepareFirstFactor(
      .init(strategy: .resetPasswordEmailCode, emailAddressId: emailAddressId)
    )
    publish()
  }

  func sendResetPasswordPhoneCode(phoneNumberId: String?) async throws {
    _ = try await engine.client.signIn.prepareFirstFactor(
      .init(strategy: .resetPasswordPhoneCode, phoneNumberId: phoneNumberId)
    )
    publish()
  }

  func verifyResetPasswordCode(_ code: String, isEmail: Bool) async throws {
    _ = try await engine.client.signIn.attemptFirstFactor(
      .init(
        strategy: isEmail ? .resetPasswordEmailCode : .resetPasswordPhoneCode,
        code: code
      )
    )
    publish()
  }

  func resetPassword(password: String, signOutOfOtherSessions: Bool) async throws {
    let signIn = try await engine.client.signIn.resetPassword(
      .init(password: password, signOutOfOtherSessions: signOutOfOtherSessions)
    )
    try await activateIfComplete(signIn)
  }

  func updateSignUp(
    emailAddress: String?,
    password: String?,
    firstName: String?,
    lastName: String?,
    username: String?,
    phoneNumber: String?,
    legalAccepted: Bool?
  ) async throws {
    let signUp = try await engine.client.signUp.update(
      .init(
        emailAddress: emailAddress,
        phoneNumber: phoneNumber,
        username: username,
        password: password,
        firstName: firstName,
        lastName: lastName,
        legalAccepted: legalAccepted
      )
    )
    try await activateIfComplete(signUp)
  }

  func updateUser(
    username: String?,
    firstName: String?,
    lastName: String?,
    primaryEmailAddressId: String?,
    primaryPhoneNumberId: String?
  ) async throws {
    await loadIfNeeded()
    _ = try await engine.user.update(
      UpdateUserParams(
        username: username,
        firstName: firstName,
        lastName: lastName,
        primaryEmailAddressId: primaryEmailAddressId,
        primaryPhoneNumberId: primaryPhoneNumberId,
        primaryWeb3WalletId: nil,
        unsafeMetadata: nil
      )
    )
    publish()
  }

  func updatePassword(currentPassword: String?, newPassword: String, signOutOfOtherSessions: Bool) async throws {
    await loadIfNeeded()
    try await engine.user.updatePassword(
      UpdateUserPasswordParams(
        newPassword: newPassword,
        currentPassword: currentPassword,
        signOutOfOtherSessions: signOutOfOtherSessions
      )
    )
    publish()
  }

  func createEmailAddress(_ emailAddress: String) async throws {
    await loadIfNeeded()
    try await engine.user.createEmailAddress(CreateEmailAddressParams(email: emailAddress))
    publish()
  }

  func createPhoneNumber(_ phoneNumber: String) async throws {
    await loadIfNeeded()
    try await engine.user.createPhoneNumber(CreatePhoneNumberParams(phoneNumber: phoneNumber))
    publish()
  }

  func createTOTP() async throws -> Data {
    await loadIfNeeded()
    let data = try await engine.user.createTOTP()
    publish()
    return data
  }

  func verifyTOTP(code: String) async throws -> Data {
    await loadIfNeeded()
    let data = try await engine.user.verifyTOTP(VerifyTOTPParams(code: code))
    publish()
    return data
  }

  func deleteUser() async throws -> Data {
    await loadIfNeeded()
    let data = try await engine.user.delete()
    publish()
    return data
  }

  private func loadIfNeeded() async {
    await ClerkRuntimeStore.loadIfNeeded(engine, key: kit.publishableKey, onto: kit)
  }

  private func publish() {
    ClerkRuntimeStore.publish(engine, onto: kit)
  }

  private func activateIfComplete(_ signIn: ClerkJSCore.Clerk.SignIn) async throws {
    if signIn.status == .complete, let sessionId = signIn.createdSessionId {
      try await engine.setActive(.init(session: sessionId))
    }
    publish()
  }

  private func activateIfComplete(_ signUp: ClerkJSCore.Clerk.SignUp) async throws {
    if let sessionId = signUp.createdSessionId {
      try await engine.setActive(.init(session: sessionId))
    }
    publish()
  }

  private func activateIfCompleteAfterRedirect() async throws {
    if let sessionId = engine.client.signIn.createdSessionId {
      try await engine.setActive(.init(session: sessionId))
    } else if let sessionId = engine.client.signUp.createdSessionId {
      try await engine.setActive(.init(session: sessionId))
    }
    publish()
  }

  private func resolvedRedirectUrl(_ redirectUrl: String) -> String {
    if redirectUrl.isEmpty {
      return ClerkJSRuntime.defaultOAuthRedirectURL.absoluteString
    }
    return redirectUrl
  }

  private func secondFactorStrategy(_ type: ClerkKit.SignIn.MfaType) -> ClerkJSCore.Clerk.SignIn.SecondFactorStrategy {
    switch type {
    case .phoneCode:
      .phoneCode
    case .emailCode:
      .emailCode
    case .totp:
      .totp
    case .backupCode:
      .backupCode
    }
  }
}

@MainActor
enum ClerkEngineBootstrap {
  static func install() {
    guard Clerk.makeEngineClient == nil else { return }
    Clerk.makeEngineClient = { kit in
      let engine = ClerkRuntimeStore.shared(for: kit.publishableKey)
      await ClerkRuntimeStore.loadIfNeeded(engine, key: kit.publishableKey, onto: kit)
      return ClerkJSEngineClient(engine: engine, kit: kit)
    }
  }
}

@MainActor
@objc(ClerkEngineBootstrapMarker)
final class ClerkEngineBootstrapMarker: NSObject {
  @objc static func installEngineFactory() {
    ClerkEngineBootstrap.install()
  }
}

#endif
