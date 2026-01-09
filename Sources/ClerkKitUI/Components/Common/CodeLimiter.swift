//
//  CodeLimiter.swift
//  Clerk
//
//  Created by Claude on 1/9/26.
//

#if os(iOS)

import Foundation

/// Tracks when verification codes were last sent to prevent excessive requests.
///
/// This class is used by both auth and user profile flows to manage code rate limiting.
/// It is injected into child views via the environment and drives countdown UI via observation.
@MainActor
@Observable
final class CodeLimiter {
  /// The default cooldown period between code requests (in seconds).
  static let defaultCooldown: TimeInterval = 30

  /// Tracks when the last code was sent for each identifier.
  private(set) var lastCodeSentAt: [String: Date] = [:]

  /// A tick counter that increments every second while any cooldown is active.
  /// Views that access `remainingCooldown(for:)` will re-render when this changes.
  private(set) var tick: UInt = 0

  /// The timer that drives the tick updates.
  private var timer: Timer?

  /// Creates a new CodeLimiter instance.
  init() {}

  /// Checks if this is the first code request for the given identifier.
  ///
  /// - Parameter identifier: The identifier to check.
  /// - Returns: `true` if no code has been sent yet for this identifier.
  func isFirstRequest(for identifier: String) -> Bool {
    lastCodeSentAt[identifier] == nil
  }

  /// Records that a code was sent for the given identifier and starts the countdown timer.
  ///
  /// - Parameter identifier: The identifier that received the code.
  func recordCodeSent(for identifier: String) {
    lastCodeSentAt[identifier] = .now
    startTimerIfNeeded()
  }

  /// Starts the countdown timer if not already running.
  private func startTimerIfNeeded() {
    guard timer == nil else { return }
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.onTick()
      }
    }
    RunLoop.current.add(timer!, forMode: .common)
  }

  /// Called every second by the timer.
  private func onTick() {
    tick &+= 1

    // Stop the timer if all cooldowns have expired
    let hasActiveCooldown = lastCodeSentAt.values.contains { date in
      Date.now.timeIntervalSince(date) < Self.defaultCooldown
    }
    if !hasActiveCooldown {
      stopTimer()
    }
  }

  /// Stops the countdown timer.
  private func stopTimer() {
    timer?.invalidate()
    timer = nil
  }

  /// Clears the code sent record for the given identifier.
  ///
  /// Call this when verification succeeds to reset the state.
  ///
  /// - Parameter identifier: The identifier to clear.
  func clearRecord(for identifier: String) {
    lastCodeSentAt[identifier] = nil
  }

  /// Returns the remaining cooldown time for the given identifier.
  ///
  /// This method accesses the `tick` property to ensure views re-render every second
  /// while the cooldown is active.
  ///
  /// - Parameters:
  ///   - identifier: The identifier to check.
  ///   - cooldown: The cooldown period in seconds. Defaults to 30 seconds.
  /// - Returns: The remaining seconds until a new code can be sent, or 0 if ready.
  func remainingCooldown(for identifier: String, cooldown: TimeInterval = defaultCooldown) -> Int {
    // Access tick to establish observation dependency for SwiftUI updates
    _ = tick
    guard let lastSent = lastCodeSentAt[identifier] else { return 0 }
    let elapsed = Date.now.timeIntervalSince(lastSent)
    return max(0, Int(cooldown - elapsed))
  }

  /// Checks if a new code can be sent for the given identifier.
  ///
  /// - Parameters:
  ///   - identifier: The identifier to check.
  ///   - cooldown: The cooldown period in seconds. Defaults to 30 seconds.
  /// - Returns: `true` if enough time has passed since the last code was sent.
  func canSendCode(for identifier: String, cooldown: TimeInterval = defaultCooldown) -> Bool {
    remainingCooldown(for: identifier, cooldown: cooldown) == 0
  }
}

#endif
