import Foundation

package enum EngineTokenLookup {
  case unavailable
  case token(String?)
}

@MainActor
package protocol ClerkEngineClient: AnyObject {
  func signIn(identifier: String) async throws
  func signInWithEmailCode(emailAddress: String) async throws
  func signInWithPhoneCode(phoneNumber: String) async throws
  func signInWithPassword(identifier: String, password: String) async throws
  func sendEmailCode(emailAddressId: String?) async throws
  func sendPhoneCode(phoneNumberId: String?) async throws
  func verifyEmailCode(_ code: String) async throws
  func verifyPhoneCode(_ code: String) async throws
  func authenticateWithPassword(_ password: String) async throws
  func setActive(sessionId: String, organizationId: String?) async throws
  func getToken(template: String?, skipCache: Bool) async throws -> String?
  func signUp(
    emailAddress: String?,
    password: String?,
    firstName: String?,
    lastName: String?,
    username: String?,
    phoneNumber: String?,
    legalAccepted: Bool?,
    transfer: Bool
  ) async throws
  func sendSignUpEmailCode() async throws
  func sendSignUpPhoneCode() async throws
  func verifySignUpEmailCode(_ code: String) async throws
  func verifySignUpPhoneCode(_ code: String) async throws
  func authenticateWithRedirect(strategy: String, redirectUrl: String, identifier: String?) async throws
  func createPasskeySignIn() async throws
  func authenticateWithPasskey(autofill: Bool) async throws
  func sendMfaPhoneCode(phoneNumberId: String?) async throws
  func sendMfaEmailCode(emailAddressId: String?) async throws
  func verifyMfaCode(_ code: String, type: SignIn.MfaType) async throws
  func sendResetPasswordEmailCode(emailAddressId: String?) async throws
  func sendResetPasswordPhoneCode(phoneNumberId: String?) async throws
  func verifyResetPasswordCode(_ code: String, isEmail: Bool) async throws
  func resetPassword(password: String, signOutOfOtherSessions: Bool) async throws
  func updateSignUp(
    emailAddress: String?,
    password: String?,
    firstName: String?,
    lastName: String?,
    username: String?,
    phoneNumber: String?,
    legalAccepted: Bool?
  ) async throws
}

extension Clerk {
  @MainActor
  package static var engineClient: (any ClerkEngineClient)?

  @MainActor
  package static var makeEngineClient: (@MainActor (Clerk) async -> any ClerkEngineClient)?

  @MainActor
  package static func resolvedEngineClient() async -> (any ClerkEngineClient)? {
    if let engineClient {
      return engineClient
    }
    guard let makeEngineClient else {
      return nil
    }
    let created = await makeEngineClient(shared)
    engineClient = created
    return created
  }

  @MainActor
  package static func engineGetToken(template: String?, skipCache: Bool) async throws -> EngineTokenLookup {
    guard let engine = await resolvedEngineClient() else {
      return .unavailable
    }
    return try await .token(engine.getToken(template: template, skipCache: skipCache))
  }

  @MainActor
  package static func requireEngineSignIn() throws -> SignIn {
    guard let signIn = shared.client?.signIn else {
      throw ClerkClientError(message: "Sign-in did not produce a client.")
    }
    return signIn
  }

  @MainActor
  package static func requireEngineSignUp() throws -> SignUp {
    guard let signUp = shared.client?.signUp else {
      throw ClerkClientError(message: "Sign-up did not produce a client.")
    }
    return signUp
  }

  @MainActor
  package static func requireEngineTransferResult() throws -> TransferFlowResult {
    if let signUp = shared.client?.signUp, signUp.status != .abandoned {
      return .signUp(signUp)
    }
    if let signIn = shared.client?.signIn {
      return .signIn(signIn)
    }
    throw ClerkClientError(message: "OAuth did not produce a client.")
  }

  @MainActor
  package static func redirectEngineClient(
    prefersEphemeralWebBrowserSession: Bool,
    transferable: Bool,
    unsafeMetadata: JSON?
  ) async -> (any ClerkEngineClient)? {
    guard !prefersEphemeralWebBrowserSession, transferable, unsafeMetadata == nil else {
      return nil
    }
    return await resolvedEngineClient()
  }

  @MainActor
  package static func installLinkedEngineFactoryIfAvailable() {
    guard makeEngineClient == nil else { return }
    guard !EnvironmentDetection.isRunningInTests else { return }
    guard let marker = NSClassFromString("ClerkEngineBootstrapMarker") as? NSObject.Type else {
      return
    }
    _ = marker.perform(NSSelectorFromString("installEngineFactory"))
  }
}
