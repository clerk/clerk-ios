//
//  CodeLimiter.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation

@MainActor
@Observable
final class CodeLimiter {
  static let defaultCooldown: TimeInterval = 30

  private(set) var lastCodeSentAt: [String: Date] = [:]

  /// A tick counter that increments every second while any cooldown is active.
  /// Views that access `remainingCooldown(for:)` will re-render when this changes.
  private(set) var tick: UInt = 0

  private var timer: Timer?

  init() {}

  func isFirstRequest(for identifier: String) -> Bool {
    lastCodeSentAt[identifier] == nil
  }

  func recordCodeSent(for identifier: String) {
    lastCodeSentAt[identifier] = .now
    startTimerIfNeeded()
  }

  private func startTimerIfNeeded() {
    guard timer == nil else { return }
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
      guard let self else {
        timer.invalidate()
        return
      }
      Task { @MainActor in
        self.onTick()
      }
    }
    RunLoop.current.add(timer!, forMode: .common)
  }

  private func onTick() {
    tick &+= 1

    let hasActiveCooldown = lastCodeSentAt.values.contains { date in
      Date.now.timeIntervalSince(date) < Self.defaultCooldown
    }
    if !hasActiveCooldown {
      stopTimer()
    }
  }

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
    let remaining = cooldown - elapsed
    return max(0, Int(ceil(remaining)))
  }

  func canSendCode(for identifier: String, cooldown: TimeInterval = defaultCooldown) -> Bool {
    remainingCooldown(for: identifier, cooldown: cooldown) == 0
  }
}

#endif
