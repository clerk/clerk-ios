//
//  SessionPollingManagerTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

/// Mock session provider for testing polling behavior
@MainActor
final class MockSessionProvider: SessionProviding {
  var sessionToReturn: Session?

  var session: Session? {
    sessionToReturn
  }

  init(session: Session? = nil) {
    sessionToReturn = session
  }
}

/// Tests for SessionPollingManager ensuring proper polling behavior and cleanup.
@MainActor
@Suite(.serialized)
struct SessionPollingManagerTests {
  @Test
  func stopPollingMultipleTimes() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(
      sessionProvider: provider,
      pollInterval: 0.1,
      pollTolerance: 0.01
    )

    manager.startPolling()

    // Stop polling should work without error
    manager.stopPolling()

    // Calling stopPolling multiple times should be safe
    manager.stopPolling()
    manager.stopPolling()

    // Verify manager is still in valid state (can start again)
    manager.startPolling()
    manager.stopPolling()
  }

  @Test
  func startPollingMultipleTimes() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(
      sessionProvider: provider,
      pollInterval: 0.1,
      pollTolerance: 0.01
    )

    // Start polling multiple times - should not crash
    manager.startPolling()
    manager.startPolling()
    manager.startPolling()

    // Should be able to stop after multiple starts
    manager.stopPolling()
  }
}

// MARK: - Backoff Tests

@MainActor
@Suite(.serialized)
struct SessionPollingManagerBackoffTests {
  @Test
  func consecutiveFailuresStartsAtZero() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider)

    #expect(manager.consecutiveFailures == 0)
  }

  @Test
  func updateBackoffStateIncrementsOnFailure() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider)

    manager.updateBackoffState(success: false)
    #expect(manager.consecutiveFailures == 1)

    manager.updateBackoffState(success: false)
    #expect(manager.consecutiveFailures == 2)

    manager.updateBackoffState(success: false)
    #expect(manager.consecutiveFailures == 3)
  }

  @Test
  func updateBackoffStateResetsOnSuccess() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider)

    // Simulate multiple failures
    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    #expect(manager.consecutiveFailures == 3)

    // Success should reset to zero
    manager.updateBackoffState(success: true)
    #expect(manager.consecutiveFailures == 0)
  }

  @Test
  func calculateBaseBackoffIntervalReturnsBaseIntervalWithNoFailures() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(
      sessionProvider: provider,
      pollInterval: 5.0
    )

    #expect(manager.calculateBaseBackoffInterval() == 5.0)
  }

  @Test
  func calculateBaseBackoffIntervalDoublesWithEachFailure() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(
      sessionProvider: provider,
      pollInterval: 5.0,
      maxPollInterval: 1000.0 // High cap to test exponential growth
    )

    // 1 failure: 5 * 2^1 = 10
    manager.updateBackoffState(success: false)
    #expect(manager.calculateBaseBackoffInterval() == 10.0)

    // 2 failures: 5 * 2^2 = 20
    manager.updateBackoffState(success: false)
    #expect(manager.calculateBaseBackoffInterval() == 20.0)

    // 3 failures: 5 * 2^3 = 40
    manager.updateBackoffState(success: false)
    #expect(manager.calculateBaseBackoffInterval() == 40.0)

    // 4 failures: 5 * 2^4 = 80
    manager.updateBackoffState(success: false)
    #expect(manager.calculateBaseBackoffInterval() == 80.0)
  }

  @Test
  func calculateBaseBackoffIntervalCapsAtMaxInterval() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(
      sessionProvider: provider,
      pollInterval: 5.0,
      maxPollInterval: 60.0
    )

    // Simulate many failures to exceed the cap
    for _ in 0 ..< 10 {
      manager.updateBackoffState(success: false)
    }

    // Should be capped at maxPollInterval
    #expect(manager.calculateBaseBackoffInterval() == 60.0)
  }

  @Test
  func calculateBackoffIntervalIncludesJitter() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(
      sessionProvider: provider,
      pollInterval: 5.0,
      maxPollInterval: 60.0
    )

    // Simulate 2 failures: base interval should be 20.0
    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)

    let baseInterval = manager.calculateBaseBackoffInterval()
    #expect(baseInterval == 20.0)

    // Run multiple times to verify intervals stay within expected jitter range (±20%).
    let minExpected = baseInterval * 0.8
    let maxExpected = baseInterval * 1.2
    for _ in 0 ..< 100 {
      let interval = manager.calculateBackoffInterval()
      #expect(interval >= minExpected && interval <= maxExpected,
              "Interval \(interval) should be within ±20% of \(baseInterval)")
    }
  }

  @Test
  func backoffResetsToBaseIntervalAfterSuccess() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(
      sessionProvider: provider,
      pollInterval: 5.0,
      maxPollInterval: 60.0
    )

    // Simulate failures to build up backoff
    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    #expect(manager.calculateBaseBackoffInterval() == 40.0)

    // Success resets the backoff
    manager.updateBackoffState(success: true)
    #expect(manager.calculateBaseBackoffInterval() == 5.0)
  }

  @Test
  func defaultMaxPollIntervalIs60Seconds() {
    #expect(SessionPollingManager.defaultMaxPollInterval == 60.0)
  }

  @Test
  func customMaxPollIntervalIsRespected() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(
      sessionProvider: provider,
      pollInterval: 5.0,
      maxPollInterval: 30.0 // Custom max
    )

    // Simulate many failures
    for _ in 0 ..< 10 {
      manager.updateBackoffState(success: false)
    }

    // Should be capped at custom maxPollInterval
    #expect(manager.calculateBaseBackoffInterval() == 30.0)
  }

  @Test
  func backoffProgressionMatchesExpectedSequence() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(
      sessionProvider: provider,
      pollInterval: 5.0,
      maxPollInterval: 60.0
    )

    // Expected progression: 5 -> 10 -> 20 -> 40 -> 60 (capped)
    let expectedIntervals: [TimeInterval] = [5.0, 10.0, 20.0, 40.0, 60.0, 60.0]

    // No failures - base interval
    #expect(manager.calculateBaseBackoffInterval() == expectedIntervals[0])

    // Each failure should progress through the sequence
    for i in 1 ..< expectedIntervals.count {
      manager.updateBackoffState(success: false)
      #expect(manager.calculateBaseBackoffInterval() == expectedIntervals[i],
              "After \(i) failure(s), expected \(expectedIntervals[i])")
    }
  }
}
