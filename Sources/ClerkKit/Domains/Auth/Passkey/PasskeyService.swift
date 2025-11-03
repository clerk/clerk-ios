//
//  PasskeyService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import AuthenticationServices
import FactoryKit
import Foundation

extension Container {

  var passkeyService: Factory<PasskeyServiceProtocol> {
    self { PasskeyService() }
  }

}

protocol PasskeyServiceProtocol: Sendable {
  @MainActor func create() async throws -> Passkey
  @MainActor func update(passkeyId: String, name: String) async throws -> Passkey
  @MainActor func attemptVerification(passkeyId: String, credential: String) async throws -> Passkey
  @MainActor func delete(passkeyId: String) async throws -> DeletedObject
}

final class PasskeyService: PasskeyServiceProtocol {

  private var apiClient: APIClient { Container.shared.apiClient() }

  @MainActor
  func create() async throws -> Passkey {
    let request = Request<ClientResponse<Passkey>>(
      path: "/v1/me/passkeys",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func update(passkeyId: String, name: String) async throws -> Passkey {
    let request = Request<ClientResponse<Passkey>>(
      path: "/v1/me/passkeys/\(passkeyId)",
      method: .patch,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: ["name": name]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptVerification(passkeyId: String, credential: String) async throws -> Passkey {
    let request = Request<ClientResponse<Passkey>>(
      path: "/v1/me/passkeys/\(passkeyId)/attempt_verification",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: [
        "strategy": "passkey",
        "public_key_credential": credential
      ]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func delete(passkeyId: String) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/passkeys/\(passkeyId)",
      method: .delete,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }
}
