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
/// If no handler is provided, returns `Client.mock` by default.
public final class MockClientService: ClientServiceProtocol {

  /// Custom handler for the `get()` method.
  ///
  /// If set, this handler will be called instead of the default behavior.
  /// The handler can include delays, custom logic, or return different values.
  public nonisolated(unsafe) var getHandler: (() async throws -> Client?)?

  /// Creates a new mock client service with a direct implementation of the `get()` method.
  ///
  /// - Parameter get: The implementation of the `get()` method.
  ///
  /// Example:
  /// ```swift
  /// let service = MockClientService {
  ///   try? await Task.sleep(for: .seconds(1))
  ///   return Client.mock
  /// }
  /// ```
  public init(get: @escaping () async throws -> Client?) {
    self.getHandler = get
  }

  @MainActor
  public func get() async throws -> Client? {
    guard let handler = getHandler else {
      fatalError("MockClientService.get() was called but not configured. Set a handler in the initializer.")
    }
    return try await handler()
  }
}

