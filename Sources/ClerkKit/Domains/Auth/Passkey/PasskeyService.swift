import Foundation

protocol PasskeyServiceProtocol: Sendable {
  @MainActor func attemptVerification(passkeyId: String, credential: String) async throws -> Passkey
}

final class PasskeyService: PasskeyServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func attemptVerification(passkeyId: String, credential: String) async throws -> Passkey {
    let request = Request<ClientResponse<Passkey>>(
      path: "/v1/me/passkeys/\(passkeyId)/attempt_verification",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: [
        "strategy": "passkey",
        "public_key_credential": credential,
      ]
    )

    return try await apiClient.send(request).value.response
  }
}
