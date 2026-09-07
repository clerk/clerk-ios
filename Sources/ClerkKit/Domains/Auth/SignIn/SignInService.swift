import ClerkSnapshots
import Foundation

protocol SignInServiceProtocol: Sendable {
  @MainActor func create(params: SignIn.CreateParams) async throws -> SignIn
  @MainActor func attemptFirstFactor(signInId: String, params: SignIn.AttemptFirstFactorParams) async throws -> SignIn
}

final class SignInService: SignInServiceProtocol {
  init(apiClient _: APIClient) {}

  @MainActor
  func create(params: SignIn.CreateParams) async throws -> SignIn {
    try await Clerk.js(.clerk, JSRawCall("createNativeSignIn", JSONValue(encoding: params)), as: SignIn.self)
  }

  @MainActor
  func attemptFirstFactor(signInId: String, params: SignIn.AttemptFirstFactorParams) async throws -> SignIn {
    try await Clerk.js(.clerk, JSRawCall("attemptNativeFirstFactor", JSONValue(encoding: Attempt(expectedId: signInId, params: params))), as: SignIn.self)
  }

  private struct Attempt: Encodable {
    var expectedId: String
    var params: SignIn.AttemptFirstFactorParams
  }
}
