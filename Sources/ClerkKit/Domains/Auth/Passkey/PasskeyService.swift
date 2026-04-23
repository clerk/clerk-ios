//
//  PasskeyService.swift
//  Clerk
//

import AuthenticationServices
import Foundation

protocol PasskeyServiceProtocol: Sendable {
  @MainActor func create(sessionId: String?) async throws -> Passkey
  @MainActor func update(passkeyId: String, name: String, sessionId: String?) async throws -> Passkey
  @MainActor func attemptVerification(passkeyId: String, credential: String, sessionId: String?) async throws -> Passkey
  @MainActor func delete(passkeyId: String, sessionId: String?) async throws -> DeletedObject
}

final class PasskeyService: PasskeyServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func create(sessionId: String?) async throws -> Passkey {
    let request = Request<ClientResponse<Passkey>>(
      path: "/v1/me/passkeys",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func update(passkeyId: String, name: String, sessionId: String?) async throws -> Passkey {
    let request = Request<ClientResponse<Passkey>>(
      path: "/v1/me/passkeys/\(passkeyId)",
      method: .patch,
      query: [("_clerk_session_id", value: sessionId)],
      body: ["name": name]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptVerification(passkeyId: String, credential: String, sessionId: String?) async throws -> Passkey {
    let request = Request<ClientResponse<Passkey>>(
      path: "/v1/me/passkeys/\(passkeyId)/attempt_verification",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: [
        "strategy": "passkey",
        "public_key_credential": credential,
      ]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func delete(passkeyId: String, sessionId: String?) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/passkeys/\(passkeyId)",
      method: .delete,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }
}
