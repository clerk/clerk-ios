//
//  SessionUtilsTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.tags(.unit))
struct SessionUtilsTests {
  enum CurrentSessionScenario: String, CaseIterable {
    case noLastActiveSessionId
    case noMatchingSession
    case returnsPendingSession
    case returnsSession
    case returnsCorrectSessionFromMultipleSessions

    var expectedSessionId: String? {
      switch self {
      case .noLastActiveSessionId, .noMatchingSession:
        nil
      case .returnsPendingSession, .returnsSession:
        "session1"
      case .returnsCorrectSessionFromMultipleSessions:
        "session2"
      }
    }
  }

  enum SessionChangedScenario: String, CaseIterable {
    case nilToNil
    case nilToSession
    case sessionToNil
    case sameSessionUnchanged
    case differentSessionId
    case sameSessionIdDifferentStatus
    case sameSessionIdDifferentUpdatedAt
    case noSessionToNoSession
    case noSessionToSession
    case sessionToNoSession
    case sessionBecomesInactive

    var expected: Bool {
      switch self {
      case .nilToNil, .sameSessionUnchanged, .noSessionToNoSession:
        false
      case .nilToSession, .sessionToNil, .differentSessionId, .sameSessionIdDifferentStatus,
           .sameSessionIdDifferentUpdatedAt, .noSessionToSession, .sessionToNoSession,
           .sessionBecomesInactive:
        true
      }
    }
  }

  func createSession(
    id: String,
    status: Session.SessionStatus,
    updatedAt: Date? = nil
  ) -> Session {
    let date = updatedAt ?? Date(timeIntervalSince1970: 1_609_459_200)
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

  func createClient(
    id: String,
    sessions: [Session],
    lastActiveSessionId: String?
  ) -> Client {
    Client(
      id: id,
      sessions: sessions,
      lastActiveSessionId: lastActiveSessionId,
      updatedAt: Date(timeIntervalSince1970: 1_609_459_200)
    )
  }

  // MARK: - Client.currentSession Tests

  @Test(arguments: CurrentSessionScenario.allCases)
  func currentSessionReturnsExpectedSession(for scenario: CurrentSessionScenario) {
    let client = client(for: scenario)

    #expect(client.currentSession?.id == scenario.expectedSessionId)
  }

  // MARK: - SessionUtils.sessionChanged Tests

  @Test(arguments: SessionChangedScenario.allCases)
  func sessionChangedReturnsExpectedValue(for scenario: SessionChangedScenario) {
    let clients = clients(for: scenario)
    let changed = SessionUtils.sessionChanged(previousClient: clients.previous, currentClient: clients.current)

    #expect(changed == scenario.expected)
  }

  private func client(for scenario: CurrentSessionScenario) -> Client {
    switch scenario {
    case .noLastActiveSessionId:
      let session = createSession(id: "session1", status: .active)
      return createClient(id: "client1", sessions: [session], lastActiveSessionId: nil)
    case .noMatchingSession:
      let session = createSession(id: "session1", status: .active)
      return createClient(id: "client1", sessions: [session], lastActiveSessionId: "nonexistent")
    case .returnsPendingSession:
      let session = createSession(id: "session1", status: .pending)
      return createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")
    case .returnsSession:
      let session = createSession(id: "session1", status: .active)
      return createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")
    case .returnsCorrectSessionFromMultipleSessions:
      let session1 = createSession(id: "session1", status: .active)
      let session2 = createSession(id: "session2", status: .active)
      let session3 = createSession(id: "session3", status: .pending)
      return createClient(
        id: "client1",
        sessions: [session1, session2, session3],
        lastActiveSessionId: "session2"
      )
    }
  }

  private func clients(for scenario: SessionChangedScenario) -> (previous: Client?, current: Client?) {
    switch scenario {
    case .nilToNil:
      return (nil, nil)
    case .nilToSession:
      let session = createSession(id: "session1", status: .active)
      let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")
      return (nil, client)
    case .sessionToNil:
      let session = createSession(id: "session1", status: .active)
      let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")
      return (client, nil)
    case .sameSessionUnchanged:
      let session = createSession(id: "session1", status: .active)
      let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")
      return (client, client)
    case .differentSessionId:
      let session1 = createSession(id: "session1", status: .active)
      let session2 = createSession(id: "session2", status: .active)
      let previous = createClient(id: "client1", sessions: [session1], lastActiveSessionId: "session1")
      let current = createClient(id: "client1", sessions: [session2], lastActiveSessionId: "session2")
      return (previous, current)
    case .sameSessionIdDifferentStatus:
      let previousSession = createSession(id: "session1", status: .active)
      let currentSession = createSession(id: "session1", status: .pending)
      let previous = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")
      let current = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")
      return (previous, current)
    case .sameSessionIdDifferentUpdatedAt:
      let previousSession = createSession(
        id: "session1",
        status: .active,
        updatedAt: Date(timeIntervalSince1970: 1_609_459_200)
      )
      let currentSession = createSession(
        id: "session1",
        status: .active,
        updatedAt: Date(timeIntervalSince1970: 1_609_459_300)
      )
      let previous = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")
      let current = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")
      return (previous, current)
    case .noSessionToNoSession:
      let previous = createClient(id: "client1", sessions: [], lastActiveSessionId: nil)
      let current = createClient(id: "client1", sessions: [], lastActiveSessionId: nil)
      return (previous, current)
    case .noSessionToSession:
      let session = createSession(id: "session1", status: .active)
      let previous = createClient(id: "client1", sessions: [], lastActiveSessionId: nil)
      let current = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")
      return (previous, current)
    case .sessionToNoSession:
      let session = createSession(id: "session1", status: .active)
      let previous = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")
      let current = createClient(id: "client1", sessions: [], lastActiveSessionId: nil)
      return (previous, current)
    case .sessionBecomesInactive:
      let previousSession = createSession(id: "session1", status: .active)
      let currentSession = createSession(id: "session1", status: .expired)
      let previous = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")
      let current = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")
      return (previous, current)
    }
  }
}
