//
//  MockClientService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Mock implementation of `ClientServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of `get()` through a handler closure.
/// Returns default mock values if handler is not provided.
public final class MockClientService: ClientServiceProtocol {
  /// Custom handler for the `get()` method.
  ///
  /// If set, this handler will be called instead of the default behavior.
  /// The handler can include delays, custom logic, or return different values.
  public nonisolated(unsafe) var getHandler: (() async throws -> Client?)?

  /// Creates a new mock client service with an optional implementation of the `get()` method.
  ///
  /// - Parameter get: Optional implementation of the `get()` method. If not provided, returns `Client.mock`.
  ///
  /// Example:
  /// ```swift
  /// let service = MockClientService {
  ///   try? await Task.sleep(for: .seconds(1))
  ///   return Client.mock
  /// }
  /// ```
  public init(get: (() async throws -> Client?)? = nil) {
    getHandler = get
  }

  @MainActor
  public func get() async throws -> Client? {
    if let handler = getHandler {
      return try await handler()
    }
    return .mock
  }
}
