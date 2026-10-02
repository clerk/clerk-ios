//
//  SessionPollingManagerTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@MainActor
final class MockSessionProvider: SessionProviding {
  var sessionToReturn: Session?
  private(set) var sessionReadCount = 0

  var session: Session? {
    sessionReadCount += 1
    return sessionToReturn
  }

  init(session: Session? = nil) {
    sessionToReturn = session
  }
}

private func createSession(
  id: String,
  status: Session.SessionStatus
) -> Session {
  let date = Date(timeIntervalSince1970: 1_609_459_200)
  return Session(
    id: id,
    status: status,
    expireAt: date,
    abandonAt: date,
    lastActiveAt: date,
    createdAt: date,
    updatedAt: date
  )
}

@MainActor
@Suite(.serialized)
struct SessionPollingManagerTests {
  @Test
  func stopPollingMultipleTimes() async throws {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider, pollInterval: 60)

    manager.startPolling()
    #expect(manager.isPollingActive)
    try await waitUntil { provider.sessionReadCount == 1 }

    manager.stopPolling()
    #expect(!manager.isPollingActive)

    manager.stopPolling()
    manager.stopPolling()
    #expect(!manager.isPollingActive)

    manager.startPolling()
    #expect(manager.isPollingActive)
    try await waitUntil { provider.sessionReadCount == 2 }

    manager.stopPolling()
  }

  @Test
  func releasedManagerStopsPolling() throws {
    let provider = MockSessionProvider()
    weak var released: SessionPollingManager?
    let pollingTask: Task<Void, Error>

    do {
      let manager = SessionPollingManager(sessionProvider: provider, pollInterval: 60)
      released = manager
      manager.startPolling()
      pollingTask = try #require(manager.pollingTask)
    }

    #expect(released == nil)
    #expect(pollingTask.isCancelled)
  }

  @Test
  func startPollingMultipleTimes() throws {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider, pollInterval: 60)

    manager.startPolling()
    let firstTask = try #require(manager.pollingTask)
    manager.startPolling()
    manager.startPolling()

    #expect(manager.pollingTask == firstTask)
    #expect(manager.isPollingActive)

    manager.stopPolling()
    #expect(manager.pollingTask == nil)
    #expect(firstTask.isCancelled)
  }

  @Test
  func shouldRefreshReturnsFalseForNilSession() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider)

    #expect(manager.shouldRefresh(session: nil) == false)
  }

  @Test
  func shouldRefreshReturnsFalseForPendingSession() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider)

    let session = createSession(id: "session1", status: .pending)
    #expect(manager.shouldRefresh(session: session) == false)
  }

  @Test
  func shouldRefreshReturnsTrueForActiveSession() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider)

    let session = createSession(id: "session1", status: .active)
    #expect(manager.shouldRefresh(session: session) == true)
  }

  @Test
  func tokenRefreshedResetsBackoff() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider)

    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    #expect(manager.consecutiveFailures == 2)

    manager.handleAuthEvent(.tokenRefreshed(token: "token"))
    #expect(manager.consecutiveFailures == 0)
  }

  @Test
  func sessionChangedActiveResetsBackoff() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider)

    manager.startPolling()

    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    #expect(manager.consecutiveFailures == 2)

    let activeSession = createSession(id: "session1", status: .active)
    manager.handleAuthEvent(.sessionChanged(oldValue: nil, newValue: activeSession))
    #expect(manager.consecutiveFailures == 0)

    manager.stopPolling()
  }

  @Test
  func sessionChangedSameActiveDoesNotResetBackoff() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider)

    manager.startPolling()

    let session = createSession(id: "session1", status: .active)
    manager.handleAuthEvent(.sessionChanged(oldValue: nil, newValue: session))

    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    #expect(manager.consecutiveFailures == 2)

    // Same active session updated (e.g. metadata change)
    manager.handleAuthEvent(.sessionChanged(oldValue: session, newValue: session))
    #expect(manager.consecutiveFailures == 2)

    manager.stopPolling()
  }

  @Test
  func sessionChangedPendingToActiveResetsBackoff() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider)

    manager.startPolling()

    let pendingSession = createSession(id: "session1", status: .pending)
    manager.handleAuthEvent(.sessionChanged(oldValue: nil, newValue: pendingSession))

    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    #expect(manager.consecutiveFailures == 2)

    let activeSession = createSession(id: "session1", status: .active)
    manager.handleAuthEvent(.sessionChanged(oldValue: pendingSession, newValue: activeSession))
    #expect(manager.consecutiveFailures == 0)

    manager.stopPolling()
  }

  @Test
  func activatedWhilePollingResetsBackoff() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider)

    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    #expect(manager.consecutiveFailures == 2)

    manager.startPolling()

    let activeSession = createSession(id: "session1", status: .active)
    manager.handleAuthEvent(.sessionChanged(oldValue: nil, newValue: activeSession))
    #expect(manager.consecutiveFailures == 0)

    manager.stopPolling()
  }

  @Test
  func sessionChangedWhenStoppedDoesNotResetBackoff() {
    let provider = MockSessionProvider()
    let manager = SessionPollingManager(sessionProvider: provider)

    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    #expect(manager.consecutiveFailures == 2)

    let activeSession = createSession(id: "session1", status: .active)
    manager.handleAuthEvent(.sessionChanged(oldValue: nil, newValue: activeSession))
    #expect(manager.consecutiveFailures == 2)
  }

  @Test
  func restartPollingReceivesAuthEvents() async {
    let provider = MockSessionProvider()
    let emitter = EventEmitter<AuthEvent>()
    let manager = SessionPollingManager(
      sessionProvider: provider,
      authEventsProvider: { emitter.events }
    )

    manager.startPolling()
    manager.stopPolling()
    manager.startPolling()

    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    #expect(manager.consecutiveFailures == 2)

    let activeSession = createSession(id: "session1", status: .active)
    emitter.send(.sessionChanged(oldValue: nil, newValue: activeSession))
    await Task.yield()

    #expect(manager.consecutiveFailures == 0)

    manager.stopPolling()
  }

  @Test
  func refreshNowIfNeededResetsBackoffWhenSessionDoesNotRequireRefresh() async {
    let provider = MockSessionProvider()
    provider.sessionToReturn = createSession(id: "session1", status: .pending)
    let manager = SessionPollingManager(sessionProvider: provider)

    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    #expect(manager.consecutiveFailures == 2)

    await manager.refreshNowIfNeeded()
    #expect(manager.consecutiveFailures == 0)
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(1)
    while ContinuousClock.now < deadline {
      if condition() { return }
      await Task.yield()
    }
    throw ClerkClientError(message: "Timed out waiting for session poll.")
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

    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    #expect(manager.consecutiveFailures == 3)

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

    for _ in 0 ..< 10 {
      manager.updateBackoffState(success: false)
    }

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

    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)

    let baseInterval = manager.calculateBaseBackoffInterval()
    #expect(baseInterval == 20.0)

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

    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    manager.updateBackoffState(success: false)
    #expect(manager.calculateBaseBackoffInterval() == 40.0)

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
      maxPollInterval: 30.0
    )

    for _ in 0 ..< 10 {
      manager.updateBackoffState(success: false)
    }

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

    let expectedIntervals: [TimeInterval] = [5.0, 10.0, 20.0, 40.0, 60.0, 60.0]

    #expect(manager.calculateBaseBackoffInterval() == expectedIntervals[0])

    for i in 1 ..< expectedIntervals.count {
      manager.updateBackoffState(success: false)
      #expect(manager.calculateBaseBackoffInterval() == expectedIntervals[i],
              "After \(i) failure(s), expected \(expectedIntervals[i])")
    }
  }
}
