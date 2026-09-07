import ClerkSnapshots
import Foundation

@MainActor
package protocol ClerkEngineClient: AnyObject {
  func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue
  func authenticateWithRedirect(strategy: String, redirectUrl: String, identifier: String?) async throws
  func authenticateSignUpWithRedirect(strategy: String, redirectUrl: String, emailAddress: String?) async throws
  func authenticateWithPasskey(autofill: Bool) async throws
  func startSessionVerification(level: String) async throws -> SessionVerification
  func prepareSessionFirstFactor(
    strategy: String,
    emailAddressId: String?,
    phoneNumberId: String?,
    enterpriseConnectionId: String?,
    redirectUrl: String?
  ) async throws -> SessionVerification
  func attemptSessionFirstFactor(
    strategy: String,
    code: String?,
    password: String?,
    publicKeyCredential: String?
  ) async throws -> SessionVerification
  func prepareSessionSecondFactor(strategy: String, phoneNumberId: String?) async throws -> SessionVerification
  func attemptSessionSecondFactor(
    strategy: String,
    code: String?,
    publicKeyCredential: String?
  ) async throws -> SessionVerification
  func verifySessionWithPasskey() async throws -> SessionVerification
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
  package static func requireEngineClient() async throws -> any ClerkEngineClient {
    guard let engine = await resolvedEngineClient() else {
      throw ClerkClientError(message: "Clerk JS engine is not available.")
    }
    return engine
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
  package static func installLinkedEngineFactoryIfAvailable() {
    guard makeEngineClient == nil else { return }
    guard !EnvironmentDetection.isRunningInTests else { return }
    guard let marker = NSClassFromString("ClerkEngineBootstrapMarker") as? NSObject.Type else {
      return
    }
    _ = marker.perform(NSSelectorFromString("installEngineFactory"))
  }
}
