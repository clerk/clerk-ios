//
//  ClerkRuntimeScope.swift
//  ClerkKit
//

import Foundation

/// Identifies the Clerk configuration epoch that an SDK-owned dependency belongs to.
///
/// Normal app and domain code should use `Clerk.shared`, `self`, or an injected `Clerk`
/// reference. Use `ClerkRuntimeScope` only for dependencies that can outlive a runtime
/// reconfiguration boundary, such as networking pipelines and response middleware.
struct ClerkRuntimeScope {
  private let epoch: ClerkConfigurationEpoch
  private let runtimeState: ClerkRuntimeState
  private let clerkProvider: @Sendable @MainActor () -> Clerk

  init(
    epoch: ClerkConfigurationEpoch,
    runtimeState: ClerkRuntimeState? = nil,
    clerkProvider: @escaping @Sendable @MainActor () -> Clerk = { Clerk.shared }
  ) {
    self.epoch = epoch
    self.runtimeState = runtimeState ?? ClerkRuntimeState(epoch: epoch)
    self.clerkProvider = clerkProvider
  }

  @MainActor
  static func current(
    clerkProvider: @escaping @Sendable @MainActor () -> Clerk = { Clerk.shared }
  ) -> ClerkRuntimeScope {
    let clerk = clerkProvider()
    return .init(
      epoch: clerk.configurationEpoch,
      runtimeState: clerk.runtimeState,
      clerkProvider: clerkProvider
    )
  }

  func validateStableRuntime() throws {
    try runtimeState.validate(epoch: epoch)
  }

  @MainActor
  func requireCurrentClerk() throws -> Clerk {
    try validateStableRuntime()
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
}

struct ClerkConfigurationEpoch: Equatable {
  static let initial = ClerkConfigurationEpoch(rawValue: 0)

  private let rawValue: Int

  func next() -> ClerkConfigurationEpoch {
    ClerkConfigurationEpoch(rawValue: rawValue + 1)
  }
}

final class ClerkRuntimeState: @unchecked Sendable {
  private let lock = NSLock()
  private var epoch: ClerkConfigurationEpoch
  private var isReconfiguring = false

  init(epoch: ClerkConfigurationEpoch = .initial) {
    self.epoch = epoch
  }

  func beginReconfiguration() {
    lock.lock()
    defer { lock.unlock() }
    isReconfiguring = true
  }

  func endReconfiguration() {
    lock.lock()
    defer { lock.unlock() }
    isReconfiguring = false
  }

  func advance(to epoch: ClerkConfigurationEpoch) {
    lock.lock()
    defer { lock.unlock() }
    self.epoch = epoch
  }

  func isCurrent(_ epoch: ClerkConfigurationEpoch) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return !isReconfiguring && self.epoch == epoch
  }

  func validate(epoch: ClerkConfigurationEpoch) throws {
    guard isCurrent(epoch) else {
      throw CancellationError()
    }
  }
}
