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
