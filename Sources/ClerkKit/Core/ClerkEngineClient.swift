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
  package static func installLinkedEngineFactoryIfAvailable() {
    guard makeEngineClient == nil else { return }
    guard !EnvironmentDetection.isRunningInTests else { return }
    guard let marker = NSClassFromString("ClerkEngineBootstrapMarker") as? NSObject.Type else {
      return
    }
    _ = marker.perform(NSSelectorFromString("installEngineFactory"))
  }
}
