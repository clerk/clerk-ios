//
//  SessionPollingManager.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Protocol defining an interface for providing the current session.
///
/// Implementations of this protocol can provide the current active session
/// for token refresh operations.
protocol SessionProviding: Sendable {
  /// Returns the current active session, if available.
  @MainActor var session: Session? { get }
}

/// Manages periodic polling of session tokens to keep them refreshed.
///
/// This class handles the background task that periodically refreshes session tokens
/// to ensure they remain valid. Call `stopPolling()` before releasing the manager.
@MainActor
final class SessionPollingManager {
  /// The interval between token refresh attempts.
  static let defaultPollInterval: TimeInterval = 5.0

  /// The tolerance for the polling interval to allow for system scheduling flexibility.
  static let defaultPollTolerance: TimeInterval = 0.1

  /// The maximum interval between polling attempts when backing off due to failures.
  static let defaultMaxPollInterval: TimeInterval = 60.0

  /// Task that performs the periodic token polling.
  private var pollingTask: Task<Void, Error>?

  /// The provider that supplies the current session for token retrieval.
  private let sessionProvider: any SessionProviding

  /// The interval between polling attempts.
  private let pollInterval: TimeInterval

  /// The tolerance for the polling interval.
  private let pollTolerance: TimeInterval

  /// The maximum interval between polling attempts when backing off.
  let maxPollInterval: TimeInterval

  /// The number of consecutive failures for backoff calculation.
  private(set) var consecutiveFailures: Int = 0

  /// Creates a new session polling manager.
  ///
  /// - Parameters:
  ///   - sessionProvider: The object that provides the current active session.
  ///   - pollInterval: The interval between polling attempts. Defaults to 5 seconds.
  ///   - pollTolerance: The tolerance for the polling interval. Defaults to 0.1 seconds.
  ///   - maxPollInterval: The maximum interval when backing off due to failures. Defaults to 60 seconds.
  init(
    sessionProvider: any SessionProviding,
    pollInterval: TimeInterval = defaultPollInterval,
    pollTolerance: TimeInterval = defaultPollTolerance,
    maxPollInterval: TimeInterval = defaultMaxPollInterval
  ) {
    self.sessionProvider = sessionProvider
    self.pollInterval = pollInterval
    self.pollTolerance = pollTolerance
    self.maxPollInterval = maxPollInterval
  }

  /// Starts polling for session tokens.
  ///
  /// If polling is already active, this method does nothing. The polling will continue
  /// until explicitly stopped or the manager is deallocated.
  func startPolling() {
    guard pollingTask == nil || pollingTask?.isCancelled == true else {
      return
    }

    let tolerance = pollTolerance

    pollingTask = Task(priority: .background) { [weak self] in
      repeat {
        let interval = await self?.refreshAndCalculateInterval() ?? Self.defaultPollInterval
        try await Task.sleep(for: .seconds(interval), tolerance: .seconds(tolerance))
      } while !Task.isCancelled
    }
  }

  /// Stops polling for session tokens.
  ///
  /// This is called by `Clerk.cleanupManagers()` during reconfiguration or test cleanup.
  func stopPolling() {
    pollingTask?.cancel()
    pollingTask = nil
  }

  /// Calculates the backoff interval based on consecutive failures.
  ///
  /// Uses exponential backoff with jitter: the interval doubles with each failure,
  /// capped at `maxPollInterval`, with ±20% randomness to prevent thundering herd.
  ///
  /// - Returns: The interval to wait before the next polling attempt.
  func calculateBackoffInterval() -> TimeInterval {
    guard consecutiveFailures > 0 else { return pollInterval }

    // Exponential backoff: baseInterval * 2^failures
    let exponentialInterval = pollInterval * pow(2.0, Double(consecutiveFailures))
    let cappedInterval = min(exponentialInterval, maxPollInterval)

    // Add jitter: ±20% randomness
    let jitter = cappedInterval * Double.random(in: -0.2 ... 0.2)
    return cappedInterval + jitter
  }

  /// Calculates the base backoff interval without jitter for testing purposes.
  ///
  /// - Returns: The base interval before jitter is applied.
  func calculateBaseBackoffInterval() -> TimeInterval {
    guard consecutiveFailures > 0 else { return pollInterval }

    let exponentialInterval = pollInterval * pow(2.0, Double(consecutiveFailures))
    return min(exponentialInterval, maxPollInterval)
  }

  /// Updates the backoff state based on the success or failure of the last refresh attempt.
  ///
  /// - Parameter success: Whether the last refresh attempt succeeded.
  func updateBackoffState(success: Bool) {
    if success {
      consecutiveFailures = 0
    } else {
      consecutiveFailures += 1
    }
  }

  /// Refreshes the token and calculates the next polling interval.
  ///
  /// This method combines the refresh, state update, and interval calculation
  /// into a single async operation.
  ///
  /// - Returns: The interval to wait before the next polling attempt.
  private func refreshAndCalculateInterval() async -> TimeInterval {
    let success = await refreshTokenIfNeeded()
    updateBackoffState(success: success)
    return calculateBackoffInterval()
  }

  /// Refreshes the token for the current session if one exists.
  ///
  /// - Returns: `true` if the refresh succeeded or no session exists, `false` if it failed.
  private func refreshTokenIfNeeded() async -> Bool {
    guard let session = sessionProvider.session else {
      return true // No session = not a failure
    }

    do {
      _ = try await session.getToken()
      return true
    } catch {
      return false
    }
  }

  /// Cancels polling and cleans up resources if the manager is released unexpectedly.
  @MainActor
  deinit {
    stopPolling()
  }
}
