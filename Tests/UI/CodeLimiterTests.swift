#if os(iOS) || os(macOS)

@testable import ClerkKitUI
import Foundation
import os
import Testing

@MainActor
struct CodeLimiterTests {
  @Test(.timeLimit(.minutes(1)))
  func countdownUpdatesUntilItsOwnCooldownEnds() async throws {
    let limiter = CodeLimiter()
    limiter.recordCodeSent(for: "identifier", cooldown: 5)

    #expect(limiter.remainingCooldown(for: "identifier") > 0)
    let update = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    defer { update.continuation.finish() }
    _ = withObservationTracking {
      limiter.remainingCooldown(for: "identifier")
    } onChange: {
      update.continuation.yield()
    }
    var updateIterator = update.stream.makeAsyncIterator()
    try #require(await updateIterator.next() != nil)

    while limiter.remainingCooldown(for: "identifier") > 0 {
      try await Task.sleep(for: .milliseconds(100))
    }
    #expect(try await !publishesUpdate { limiter.remainingCooldown(for: "identifier") })
  }

  private func publishesUpdate(_ read: () -> Int) async throws -> Bool {
    let didChange = OSAllocatedUnfairLock(initialState: false)
    _ = withObservationTracking(read) {
      didChange.withLock { $0 = true }
    }
    try await Task.sleep(for: .seconds(2))
    return didChange.withLock { $0 }
  }
}

#endif
