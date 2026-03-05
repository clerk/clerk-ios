//
//  MockClientService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Mock implementation of `ClientServiceProtocol` for testing and previews.
///
/// Allows customizing `getResponse()` behavior for `clerk.refreshClient()`.
/// Returns default mock values if handlers are not provided.
package final class MockClientService: ClientServiceProtocol {
  @MainActor
  private var responseSequence: UInt64 = 0

  /// Custom client payload source used when `getResponseHandler` is unset.
  ///
  /// If set, this handler will be called instead of the default behavior.
  /// The handler can include delays, custom logic, or return different values.
  package nonisolated(unsafe) var getHandler: (() async throws -> Client?)?
  package nonisolated(unsafe) var getResponseHandler: (() async throws -> ClientServiceResponse)?

  /// Creates a new mock client service with an optional client payload source.
  ///
  /// - Parameter get: Optional payload source. If not provided, returns `Client.mock`.
  ///
  /// Example:
  /// ```swift
  /// let service = MockClientService {
  ///   try? await Task.sleep(for: .seconds(1))
  ///   return Client.mock
  /// }
  /// ```
  package init(get: (() async throws -> Client?)? = nil) {
    getHandler = get
  }

  @MainActor
  package func get() async throws -> Client? {
    let response = try await getResponse()
    return response.client
  }

  @MainActor
  package func getResponse() async throws -> ClientServiceResponse {
    if let handler = getResponseHandler {
      return try await handler()
    }

    let client: Client? = if let handler = getHandler {
      try await handler()
    } else {
      .mock
    }

    responseSequence &+= 1
    let requestSequence = responseSequence

    return ClientServiceResponse(
      client: client,
      requestSequence: requestSequence
    )
  }
}
