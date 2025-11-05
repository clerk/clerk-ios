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
