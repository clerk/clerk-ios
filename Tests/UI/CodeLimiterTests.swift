#if os(iOS) || os(macOS)

@testable import ClerkKitUI
import Foundation
import os
import Testing

@MainActor
struct CodeLimiterTests {
  @Test
  func countdownUpdatesUntilItsOwnCooldownEnds() {
    var currentDate = Date(timeIntervalSinceReferenceDate: 0)
    var tick: (@MainActor () -> Bool)?
    let limiter = CodeLimiter(currentDate: { currentDate }) { onTick in
      tick = onTick
      return { tick = nil }
    }
    limiter.recordCodeSent(for: "identifier", cooldown: 5)

    for remainingCooldown in (0 ..< 5).reversed() {
      currentDate += 1
      #expect(publishesUpdate(when: { _ = tick?() }) { limiter.remainingCooldown(for: "identifier") })
      #expect(limiter.remainingCooldown(for: "identifier") == remainingCooldown)
    }
    #expect(tick == nil)
  }

  @Test
  func remembersWhichIdentifierWasSentLast() {
    let limiter = CodeLimiter(startTicking: { _ in {} })
    #expect(limiter.lastCodeSentIdentifier == nil)

    limiter.recordCodeSent(for: "phone_a")
    limiter.recordCodeSent(for: "phone_b")

    #expect(limiter.lastCodeSentIdentifier == "phone_b")
  }

  private func publishesUpdate(when change: () -> Void, _ read: () -> Int) -> Bool {
    let didChange = OSAllocatedUnfairLock(initialState: false)
    _ = withObservationTracking(read) {
      didChange.withLock { $0 = true }
    }
    change()
    return didChange.withLock { $0 }
  }
}

#endif
