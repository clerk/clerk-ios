//
//  MockExternalAccountService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

package final class MockExternalAccountService: ExternalAccountServiceProtocol {
  package nonisolated(unsafe) var reauthorizeHandler: ((String, String?, [String], [OIDCPrompt]) async throws -> ExternalAccount)?

  package nonisolated(unsafe) var destroyHandler: ((String) async throws -> DeletedObject)?

  package init(
    reauthorize: ((String, String?, [String], [OIDCPrompt]) async throws -> ExternalAccount)? = nil,
    destroy: ((String) async throws -> DeletedObject)? = nil
  ) {
    reauthorizeHandler = reauthorize
    destroyHandler = destroy
  }

  @MainActor
  package func reauthorize(
    _ externalAccountId: String,
    redirectUrl: String?,
    additionalScopes: [String],
    oidcPrompts: [OIDCPrompt]
  ) async throws -> ExternalAccount {
    if let handler = reauthorizeHandler {
      return try await handler(externalAccountId, redirectUrl, additionalScopes, oidcPrompts)
    }
    return .mockVerified
  }

  @MainActor
  package func destroy(_ externalAccountId: String) async throws -> DeletedObject {
    if let handler = destroyHandler {
      return try await handler(externalAccountId)
    }
    return .mock
  }
}
