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

  private var cooldownEndsAt: [String: Date] = [:]
  private var now: Date = .now
  private var timer: Timer?

  init() {}

  func isFirstRequest(for identifier: String) -> Bool {
    cooldownEndsAt[identifier] == nil
  }

  func recordCodeSent(for identifier: String, cooldown: TimeInterval = defaultCooldown) {
    now = .now
    cooldownEndsAt[identifier] = now.addingTimeInterval(cooldown)
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
    now = .now
    if !cooldownEndsAt.values.contains(where: { $0 > now }) {
      stopTimer()
    }
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
  }

  func clearRecord(for identifier: String) {
    cooldownEndsAt[identifier] = nil
  }

  func remainingCooldown(for identifier: String) -> Int {
    guard let endsAt = cooldownEndsAt[identifier] else { return 0 }
    return max(0, Int(ceil(endsAt.timeIntervalSince(now))))
  }

  func canSendCode(for identifier: String) -> Bool {
    remainingCooldown(for: identifier) == 0
  }
}

#endif
