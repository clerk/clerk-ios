import Foundation

protocol PasskeyServiceProtocol: Sendable {
  @MainActor func attemptVerification(passkeyId: String, credential: String) async throws -> Passkey
}

final class PasskeyService: PasskeyServiceProtocol {
  init(apiClient _: APIClient) {}

  @MainActor
  func attemptVerification(passkeyId: String, credential: String) async throws -> Passkey {
    try await Clerk.js(.clerk, JSRawCall("attemptNativePasskeyVerification", .string(passkeyId), .string(credential)), as: Passkey.self)
  }
}
