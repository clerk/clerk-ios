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
  private var now: Date
  private var stopTicking: (() -> Void)?
  private let currentDate: () -> Date
  private let startTicking: (_ tick: @escaping @MainActor () -> Bool) -> () -> Void

  /// - Parameters:
  ///   - currentDate: The clock used to measure cooldowns.
  ///   - startTicking: Calls `tick` every second until it returns `false`, and returns a closure that stops the ticks.
  init(
    currentDate: @escaping () -> Date = { .now },
    startTicking: @escaping (_ tick: @escaping @MainActor () -> Bool) -> () -> Void = CodeLimiter.startTimer
  ) {
    self.currentDate = currentDate
    self.startTicking = startTicking
    now = currentDate()
  }

  func isFirstRequest(for identifier: String) -> Bool {
    cooldownEndsAt[identifier] == nil
  }

  func recordCodeSent(for identifier: String, cooldown: TimeInterval = defaultCooldown) {
    now = currentDate()
    cooldownEndsAt[identifier] = now.addingTimeInterval(cooldown)
    startTimerIfNeeded()
  }

  private func startTimerIfNeeded() {
    guard stopTicking == nil else { return }
    stopTicking = startTicking { [weak self] in
      guard let self else { return false }
      onTick()
      return true
    }
  }

  private func onTick() {
    now = currentDate()
    if !cooldownEndsAt.values.contains(where: { $0 > now }) {
      stopTimer()
    }
  }

  private func stopTimer() {
    stopTicking?()
    stopTicking = nil
  }

  private nonisolated static func startTimer(_ tick: @escaping @MainActor () -> Bool) -> () -> Void {
    let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
      // Scheduled from the main actor on its run loop, so the timer fires on the main thread.
      if !MainActor.assumeIsolated(tick) {
        timer.invalidate()
      }
    }
    RunLoop.current.add(timer, forMode: .common)
    return { timer.invalidate() }
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
