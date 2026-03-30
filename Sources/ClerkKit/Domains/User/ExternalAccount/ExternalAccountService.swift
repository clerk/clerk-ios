//
//  ExternalAccountService.swift
//  Clerk
//

import Foundation

protocol ExternalAccountServiceProtocol: Sendable {
  @MainActor func reauthorize(_ externalAccountId: String, additionalScopes: [String], oidcPrompts: [OIDCPrompt]) async throws -> ExternalAccount
  @MainActor func destroy(_ externalAccountId: String) async throws -> DeletedObject
}

final class ExternalAccountService: ExternalAccountServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func reauthorize(
    _ externalAccountId: String,
    additionalScopes: [String],
    oidcPrompts: [OIDCPrompt]
  ) async throws -> ExternalAccount {
    var bodyParams: [String: JSON] = [
      "redirect_url": .string(Clerk.shared.options.redirectConfig.redirectUrl),
    ]

    if !additionalScopes.isEmpty {
      bodyParams["additional_scope"] = .array(additionalScopes.map { .string($0) })
    }

    if let serializedPrompt = try oidcPrompts.validatedPrompt() {
      bodyParams["oidc_prompt"] = .string(serializedPrompt)
    }

    let request = Request<ClientResponse<ExternalAccount>>(
      path: "/v1/me/external_accounts/\(externalAccountId)/reauthorize",
      method: .patch,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: bodyParams
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func destroy(_ externalAccountId: String) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/external_accounts/\(externalAccountId)",
      method: .delete,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }
}
