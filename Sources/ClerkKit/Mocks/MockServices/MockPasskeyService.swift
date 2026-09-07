import Foundation

package final class MockPasskeyService: PasskeyServiceProtocol {
  package nonisolated(unsafe) var attemptVerificationHandler: ((String, String) async throws -> Passkey)?

  package init(
    attemptVerification: ((String, String) async throws -> Passkey)? = nil
  ) {
    attemptVerificationHandler = attemptVerification
  }

  @MainActor
  package func attemptVerification(passkeyId: String, credential: String) async throws -> Passkey {
    if let handler = attemptVerificationHandler {
      return try await handler(passkeyId, credential)
    }
    return .mock
  }
}
