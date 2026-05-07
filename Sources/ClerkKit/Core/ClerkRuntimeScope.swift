//
//  ClerkRuntimeScope.swift
//  ClerkKit
//

import Foundation

struct ClerkConfigurationEpoch: Equatable {
  static let initial = ClerkConfigurationEpoch(rawValue: 0)

  private let rawValue: Int

  func next() -> ClerkConfigurationEpoch {
    ClerkConfigurationEpoch(rawValue: rawValue + 1)
  }
}

/// Identifies the Clerk configuration epoch that an SDK-owned dependency belongs to.
///
/// Normal app and domain code should use `Clerk.shared`, `self`, or an injected `Clerk`
/// reference. Use `ClerkRuntimeScope` only for dependencies that can outlive a runtime
/// reconfiguration boundary, such as networking pipelines and response middleware.
struct ClerkRuntimeScope {
  private let epoch: ClerkConfigurationEpoch
  private let clerkProvider: @Sendable @MainActor () -> Clerk

  init(
    epoch: ClerkConfigurationEpoch,
    clerkProvider: @escaping @Sendable @MainActor () -> Clerk = { Clerk.shared }
  ) {
    self.epoch = epoch
    self.clerkProvider = clerkProvider
  }

  @MainActor
  static func current(
    clerkProvider: @escaping @Sendable @MainActor () -> Clerk = { Clerk.shared }
  ) -> ClerkRuntimeScope {
    let clerk = clerkProvider()
    return ClerkRuntimeScope(epoch: clerk.configurationEpoch, clerkProvider: clerkProvider)
  }

  @MainActor
  var isCurrent: Bool {
    clerkProvider().isCurrentConfigurationEpoch(epoch)
  }

  @MainActor
  func requireCurrentClerk() throws -> Clerk {
    let clerk = clerkProvider()
    guard clerk.isCurrentConfigurationEpoch(epoch) else {
      throw CancellationError()
    }
    return clerk
  }

  @MainActor
  func withCurrentClerk<T>(_ operation: @MainActor (Clerk) throws -> T) throws -> T {
    let clerk = try requireCurrentClerk()
    return try operation(clerk)
  }

  @MainActor
  func validateStableRuntime() throws {
    try clerkProvider().ensureCurrentStableConfigurationEpoch(epoch)
  }
}
