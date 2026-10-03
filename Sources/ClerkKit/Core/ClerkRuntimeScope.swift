//
//  ClerkRuntimeScope.swift
//  ClerkKit
//

import Foundation

/// Identifies the Clerk runtime that an SDK-owned dependency belongs to.
///
/// Normal app and domain code should use `Clerk.shared`, `self`, or an injected `Clerk`
/// reference. Use `ClerkRuntimeScope` only for dependencies that can outlive a runtime
/// reconfiguration boundary, such as networking pipelines and response middleware.
struct ClerkRuntimeScope {
  private let state: ClerkRuntimeState
  private let clerkProvider: @Sendable @MainActor () -> Clerk

  init(
    state: ClerkRuntimeState = ClerkRuntimeState(),
    clerkProvider: @escaping @Sendable @MainActor () -> Clerk = { Clerk.shared }
  ) {
    self.state = state
    self.clerkProvider = clerkProvider
  }

  @MainActor
  static func current(
    clerkProvider: @escaping @Sendable @MainActor () -> Clerk = { Clerk.shared }
  ) -> ClerkRuntimeScope {
    .init(state: clerkProvider().runtime.state, clerkProvider: clerkProvider)
  }

  func validateStableRuntime() throws {
    try state.validate()
  }

  @MainActor
  func requireCurrentClerk() throws -> Clerk {
    try validateStableRuntime()
    let clerk = clerkProvider()
    guard clerk.runtime.state === state else {
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

struct ClientResponseGeneration: Equatable {
  static let initial = ClientResponseGeneration(rawValue: 0)

  private let rawValue: Int

  private init(rawValue: Int) {
    self.rawValue = rawValue
  }

  var propertyListValue: NSNumber {
    NSNumber(value: rawValue)
  }

  init?(propertyListValue value: Any?) {
    if let rawValue = value as? Int {
      self.init(rawValue: rawValue)
      return
    }

    guard let rawValue = value as? NSNumber else {
      return nil
    }

    self.init(rawValue: rawValue.intValue)
  }

  func next() -> ClientResponseGeneration {
    ClientResponseGeneration(rawValue: rawValue + 1)
  }
}

/// Whether the runtime a scope was built for is still the one Clerk runs.
final class ClerkRuntimeState: @unchecked Sendable {
  private let lock = NSLock()
  private var current = true

  var isCurrent: Bool {
    lock.lock()
    defer { lock.unlock() }
    return current
  }

  func retire() {
    lock.lock()
    defer { lock.unlock() }
    current = false
  }

  func reinstate() {
    lock.lock()
    defer { lock.unlock() }
    current = true
  }

  func validate() throws {
    guard isCurrent else {
      throw CancellationError()
    }
  }
}
