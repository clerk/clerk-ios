//
//  MockEnvironmentService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Mock implementation of `EnvironmentServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of `get()` through a handler closure.
/// If no handler is provided, returns `Clerk.Environment.mock` by default.
public final class MockEnvironmentService: EnvironmentServiceProtocol {

  /// Custom handler for the `get()` method.
  ///
  /// If set, this handler will be called instead of the default behavior.
  /// The handler can include delays, custom logic, or return different values.
  public nonisolated(unsafe) var getHandler: (() async throws -> Clerk.Environment)?

  /// Creates a new mock environment service with a direct implementation of the `get()` method.
  ///
  /// - Parameter get: The implementation of the `get()` method.
  ///
  /// Example:
  /// ```swift
  /// let service = MockEnvironmentService {
  ///   try? await Task.sleep(for: .seconds(1))
  ///   return Clerk.Environment.mock
  /// }
  /// ```
  public init(get: @escaping () async throws -> Clerk.Environment) {
    self.getHandler = get
  }

  @MainActor
  public func get() async throws -> Clerk.Environment {
    guard let handler = getHandler else {
      fatalError("MockEnvironmentService.get() was called but not configured. Set a handler in the initializer.")
    }
    return try await handler()
  }
}

