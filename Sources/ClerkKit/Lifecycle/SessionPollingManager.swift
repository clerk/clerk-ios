//
//  SessionPollingManager.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

protocol SessionProviding: Sendable {
  @MainActor var session: Session? { get }
}

/// Manages periodic polling of session tokens to keep them refreshed.
@MainActor
final class SessionPollingManager {
  static let defaultPollInterval: TimeInterval = 5.0

  static let defaultPollTolerance: TimeInterval = 0.1

  static let defaultMaxPollInterval: TimeInterval = 60.0

  private(set) var pollingTask: Task<Void, Error>?

  private var authEventTask: Task<Void, Never>?

  private let sessionProvider: any SessionProviding

  private let authEventsProvider: (() -> AsyncStream<AuthEvent>)?

  private let pollInterval: TimeInterval

  private let pollTolerance: TimeInterval

  let maxPollInterval: TimeInterval

  private(set) var consecutiveFailures: Int = 0
  var isPollingActive: Bool {
    pollingTask != nil && pollingTask?.isCancelled == false
  }

  init(
    sessionProvider: any SessionProviding,
    authEventsProvider: (() -> AsyncStream<AuthEvent>)? = nil,
    pollInterval: TimeInterval = defaultPollInterval,
    pollTolerance: TimeInterval = defaultPollTolerance,
    maxPollInterval: TimeInterval = defaultMaxPollInterval
  ) {
    self.sessionProvider = sessionProvider
    self.authEventsProvider = authEventsProvider
    self.pollInterval = pollInterval
    self.pollTolerance = pollTolerance
    self.maxPollInterval = maxPollInterval
  }

  func startPolling() {
    guard pollingTask == nil || pollingTask?.isCancelled == true else {
      return
    }

    startObservingAuthEvents()

    let tolerance = pollTolerance

    pollingTask = Task(priority: .background) { [weak self] in
      repeat {
        let interval = await self?.refreshAndCalculateInterval() ?? Self.defaultPollInterval
        try await Task.sleep(for: .seconds(interval), tolerance: .seconds(tolerance))
      } while !Task.isCancelled
    }
  }

  func stopPolling() {
    pollingTask?.cancel()
    pollingTask = nil
    authEventTask?.cancel()
    authEventTask = nil
  }

  /// Calculates the backoff interval based on consecutive failures.
  ///
  /// - Returns: The interval to wait before the next polling attempt.
  func calculateBackoffInterval() -> TimeInterval {
    guard consecutiveFailures > 0 else { return pollInterval }

    let cappedInterval = calculateBaseBackoffInterval()
    let jitter = cappedInterval * Double.random(in: -0.2 ... 0.2)
    return cappedInterval + jitter
  }

  func calculateBaseBackoffInterval() -> TimeInterval {
    guard consecutiveFailures > 0 else { return pollInterval }

    let exponentialInterval = pollInterval * pow(2.0, Double(consecutiveFailures))
    return min(exponentialInterval, maxPollInterval)
  }

  func updateBackoffState(success: Bool) {
    if success {
      consecutiveFailures = 0
    } else {
      consecutiveFailures += 1
    }
  }

  private func refreshAndCalculateInterval() async -> TimeInterval {
    let success = await refreshTokenIfNeeded()
    updateBackoffState(success: success)
    return calculateBackoffInterval()
  }

  func handleAuthEvent(_ event: AuthEvent) {
    switch event {
    case .tokenRefreshed:
      consecutiveFailures = 0
    case .sessionChanged(let oldValue, let newValue):
      let becameActive = newValue?.status == .active && (oldValue?.status != .active || oldValue?.id != newValue?.id)
      if becameActive, isPollingActive {
        consecutiveFailures = 0
        Task { [weak self] in
          _ = await self?.refreshTokenIfNeeded()
        }
      }
    default:
      break
    }
  }

  private func startObservingAuthEvents() {
    guard authEventTask == nil || authEventTask?.isCancelled == true else {
      return
    }
    guard let authEventsProvider else {
      return
    }

    authEventTask = Task { @MainActor [weak self] in
      for await event in authEventsProvider() {
        self?.handleAuthEvent(event)
      }
    }
  }

  /// Refreshes the token for the current session when it is active.
  ///
  /// - Returns: `true` if the refresh succeeded or no active session exists, `false` if it failed.
  private func refreshTokenIfNeeded() async -> Bool {
    guard let session = sessionProvider.session else {
      return true // No session = not a failure
    }

    guard shouldRefresh(session: session) else {
      return true
    }

    do {
      _ = try await session.getToken()
      return true
    } catch {
      return false
    }
  }

  func shouldRefresh(session: Session?) -> Bool {
    guard let session else {
      return false
    }
    return session.status == .active
  }

  func refreshNowIfNeeded() async {
    let success = await refreshTokenIfNeeded()
    updateBackoffState(success: success)
  }

  deinit {
    pollingTask?.cancel()
    pollingTask = nil
    authEventTask?.cancel()
    authEventTask = nil
  }
}
