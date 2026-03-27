//
//  MockExternalAccountService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Mock implementation of `ExternalAccountServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of service methods through handler closures.
/// All methods return default mock values if handlers are not provided.
package final class MockExternalAccountService: ExternalAccountServiceProtocol {
  /// Custom handler for the `reauthorize(_:additionalScopes:oidcPrompts:)` method.
  package nonisolated(unsafe) var reauthorizeHandler: ((String, [String], [OIDCPrompt]) async throws -> ExternalAccount)?

  /// Custom handler for the `destroy(_:)` method.
  package nonisolated(unsafe) var destroyHandler: ((String) async throws -> DeletedObject)?

  package init(
    reauthorize: ((String, [String], [OIDCPrompt]) async throws -> ExternalAccount)? = nil,
    destroy: ((String) async throws -> DeletedObject)? = nil
  ) {
    reauthorizeHandler = reauthorize
    destroyHandler = destroy
  }

  @MainActor
  package func reauthorize(
    _ externalAccountId: String,
    additionalScopes: [String],
    oidcPrompts: [OIDCPrompt]
  ) async throws -> ExternalAccount {
    if let handler = reauthorizeHandler {
      return try await handler(externalAccountId, additionalScopes, oidcPrompts)
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
