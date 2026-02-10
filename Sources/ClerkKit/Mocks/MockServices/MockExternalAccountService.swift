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
  /// Custom handler for the `destroy(_:)` method.
  package nonisolated(unsafe) var destroyHandler: ((String) async throws -> DeletedObject)?

  package init(destroy: ((String) async throws -> DeletedObject)? = nil) {
    destroyHandler = destroy
  }

  @MainActor
  package func destroy(_ externalAccountId: String) async throws -> DeletedObject {
    if let handler = destroyHandler {
      return try await handler(externalAccountId)
    }
    return .mock
  }
}
