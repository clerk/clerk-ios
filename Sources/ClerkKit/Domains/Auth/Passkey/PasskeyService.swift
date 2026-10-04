//
//  PasskeyService.swift
//  Clerk
//

import AuthenticationServices
import Foundation

protocol PasskeyServiceProtocol: Sendable {
  @MainActor func create() async throws -> Passkey
  @MainActor func update(passkeyId: String, name: String) async throws -> Passkey
  @MainActor func attemptVerification(passkeyId: String, credential: String) async throws -> Passkey
  @MainActor func delete(passkeyId: String) async throws -> DeletedObject
}

final class PasskeyService: PasskeyServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func create() async throws -> Passkey {
    let request = Request<ClientResponse<Passkey>>(
      path: "/v1/me/passkeys",
      method: .post,
      scopedToActiveSession: true
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func update(passkeyId: String, name: String) async throws -> Passkey {
    let request = Request<ClientResponse<Passkey>>(
      path: "/v1/me/passkeys/\(passkeyId)",
      method: .patch,
      scopedToActiveSession: true,
      body: ["name": name]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptVerification(passkeyId: String, credential: String) async throws -> Passkey {
    let request = Request<ClientResponse<Passkey>>(
      path: "/v1/me/passkeys/\(passkeyId)/attempt_verification",
      method: .post,
      scopedToActiveSession: true,
      body: [
        "strategy": "passkey",
        "public_key_credential": credential,
      ]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func delete(passkeyId: String) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/passkeys/\(passkeyId)",
      method: .delete,
      scopedToActiveSession: true
    )

    return try await apiClient.send(request).value.response
  }
}
