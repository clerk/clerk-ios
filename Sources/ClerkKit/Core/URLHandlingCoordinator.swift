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
  private var inFlightTasks: [ClerkURLRoute: InFlightTask] = [:]

  func handle(
    _ route: ClerkURLRoute,
    operation: @escaping @MainActor @Sendable () async throws -> TransferFlowResult
  ) async throws -> TransferFlowResult {
    if let inFlightTask = inFlightTasks[route] {
      return try await inFlightTask.task.value
    }

    let entryId = UUID()
    let task = Task { @MainActor in
      try await operation()
    }

    inFlightTasks[route] = .init(id: entryId, task: task)
    defer {
      if inFlightTasks[route]?.id == entryId {
        inFlightTasks[route] = nil
      }
    }

    return try await task.value
  }

  func cancelAll() {
    for inFlightTask in inFlightTasks.values {
      inFlightTask.task.cancel()
    }
    inFlightTasks.removeAll()
  }
}

extension URLHandlingCoordinator {
  private struct InFlightTask {
    let id: UUID
    let task: Task<TransferFlowResult, Error>
  }
}
