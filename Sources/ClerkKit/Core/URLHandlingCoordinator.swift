//
//  URLHandlingCoordinator.swift
//  Clerk
//

import Foundation

/// Coalesces duplicate Clerk URL handling operations by route identity.
///
/// When both the app-level `onOpenURL` and a prebuilt Clerk UI surface attempt
/// to handle the same callback concurrently, this actor ensures the underlying
/// auth operation only runs once.
@MainActor
final class URLHandlingCoordinator {
  private var inFlightTasks: [ClerkURLRoute: Task<SignIn, Error>] = [:]

  func handle(
    _ route: ClerkURLRoute,
    operation: @escaping @MainActor @Sendable () async throws -> SignIn
  ) async throws -> SignIn {
    if let task = inFlightTasks[route] {
      return try await task.value
    }

    let task = Task { @MainActor in
      try await operation()
    }

    inFlightTasks[route] = task
    defer { inFlightTasks[route] = nil }
    return try await task.value
  }

  func cancelAll() {
    for task in inFlightTasks.values {
      task.cancel()
    }
    inFlightTasks.removeAll()
  }
}
