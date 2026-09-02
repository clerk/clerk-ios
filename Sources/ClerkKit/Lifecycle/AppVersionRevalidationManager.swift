//
//  AppVersionRevalidationManager.swift
//  Clerk
//

import Foundation

@MainActor
protocol AppVersionRevalidationManagerDelegate: AnyObject {
  var shouldRevalidateAppVersionSupport: Bool { get }

  func revalidateAppVersionSupport() async throws
  func resumeSessionPollingAfterAppVersionRecovery() async
}

/// Periodically checks whether a server-enforced app-version block has been removed.
///
/// The manager owns retry scheduling and lifecycle cancellation. Its delegate owns
/// the actual protected request and the resulting app-version support state.
@MainActor
final class AppVersionRevalidationManager {
  weak var delegate: (any AppVersionRevalidationManagerDelegate)?

  private let retryPolicy: RetryPolicy
  private let sleep: @MainActor @Sendable (Duration) async throws -> Void

  private var revalidationTask: Task<Void, Never>?
  private var taskGeneration = 0
  private var isAppInForeground = true

  init(
    delegate: (any AppVersionRevalidationManagerDelegate)? = nil,
    initialDelay: Duration = .seconds(60),
    maximumDelay: Duration = .seconds(300),
    sleep: @escaping @MainActor @Sendable (Duration) async throws -> Void = { delay in
      try await Task.sleep(for: delay, tolerance: .seconds(5))
    }
  ) {
    self.delegate = delegate
    retryPolicy = RetryPolicy(
      maxAttempts: .max,
      initialDelay: initialDelay,
      maximumDelay: maximumDelay
    )
    self.sleep = sleep
  }

  /// Starts recovery checks when the delegate reports an unsupported app version.
  func appVersionSupportStatusDidChange() {
    startIfNeeded()
  }

  func applicationWillEnterForeground() {
    isAppInForeground = true
    startIfNeeded()
  }

  func applicationDidEnterBackground() {
    isAppInForeground = false
    stop()
  }

  func stop() {
    taskGeneration += 1
    revalidationTask?.cancel()
    revalidationTask = nil
  }

  func stopAndWait() async {
    let task = revalidationTask
    stop()
    await task?.value
  }

  private func startIfNeeded() {
    guard isAppInForeground,
          delegate?.shouldRevalidateAppVersionSupport == true,
          revalidationTask == nil
    else {
      return
    }

    taskGeneration += 1
    let generation = taskGeneration
    let retryPolicy = retryPolicy
    let sleep = sleep

    revalidationTask = Task(priority: .utility) { @MainActor [weak self] in
      defer { self?.finish(generation: generation) }

      var attempt = 1
      while !Task.isCancelled {
        let delay = Self.jitteredDelay(retryPolicy.delay(forAttempt: attempt))
        do {
          try await sleep(delay)
        } catch {
          return
        }

        guard await self?.revalidateIfNeeded() == true else {
          return
        }
        attempt += 1
      }
    }
  }

  /// Performs one protected recovery check and reports whether another is needed.
  private func revalidateIfNeeded() async -> Bool {
    guard !Task.isCancelled,
          isAppInForeground,
          let delegate,
          delegate.shouldRevalidateAppVersionSupport
    else {
      return false
    }

    do {
      try await delegate.revalidateAppVersionSupport()
    } catch is CancellationError {
      return false
    } catch {
      // A failed protected request cannot clear the server verdict.
    }

    guard !Task.isCancelled, isAppInForeground else {
      return false
    }
    if delegate.shouldRevalidateAppVersionSupport {
      return true
    }

    await delegate.resumeSessionPollingAfterAppVersionRecovery()
    return !Task.isCancelled &&
      isAppInForeground &&
      delegate.shouldRevalidateAppVersionSupport
  }

  private func finish(generation: Int) {
    guard taskGeneration == generation else {
      return
    }
    revalidationTask = nil
  }

  private static func jitteredDelay(_ delay: Duration) -> Duration {
    let components = delay.components
    let seconds = Double(components.seconds) +
      Double(components.attoseconds) / 1_000_000_000_000_000_000
    guard seconds > 0 else {
      return .zero
    }
    return .seconds(seconds * Double.random(in: 0.8 ... 1.2))
  }
}
