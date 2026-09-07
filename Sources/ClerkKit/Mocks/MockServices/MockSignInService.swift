import Foundation

package final class MockSignInService: SignInServiceProtocol {
  nonisolated(unsafe) var createHandler: ((SignIn.CreateParams) async throws -> SignIn)?
  nonisolated(unsafe) var attemptFirstFactorHandler: ((String, SignIn.AttemptFirstFactorParams) async throws -> SignIn)?

  init(
    create: ((SignIn.CreateParams) async throws -> SignIn)? = nil,
    attemptFirstFactor: ((String, SignIn.AttemptFirstFactorParams) async throws -> SignIn)? = nil
  ) {
    createHandler = create
    attemptFirstFactorHandler = attemptFirstFactor
  }

  @MainActor
  func create(params: SignIn.CreateParams) async throws -> SignIn {
    if let handler = createHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  func attemptFirstFactor(signInId: String, params: SignIn.AttemptFirstFactorParams) async throws -> SignIn {
    if let handler = attemptFirstFactorHandler {
      return try await handler(signInId, params)
    }
    return .mock
  }
}
