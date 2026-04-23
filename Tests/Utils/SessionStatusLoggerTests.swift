//
//  SessionStatusLoggerTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct SessionStatusLoggerTests {
  enum PendingSessionLoggingScenario: String, CaseIterable {
    case noSessionId
    case noMatchingSession
    case nonPendingSession
    case firstClient
    case noPreviousSession
    case sessionIdChanged
    case sessionStatusChanged
    case tasksChanged
    case tasksChangedFromNilToEmpty
    case tasksChangedFromEmptyToNil
    case noChange
    case sameTasksNil

    var expected: Bool {
      switch self {
      case .noSessionId, .noMatchingSession, .nonPendingSession, .tasksChangedFromNilToEmpty,
           .tasksChangedFromEmptyToNil, .noChange, .sameTasksNil:
        false
      case .firstClient, .noPreviousSession, .sessionIdChanged, .sessionStatusChanged, .tasksChanged:
        true
      }
    }
  }

  func createSession(
    id: String,
    status: Session.SessionStatus,
    tasks: [Session.Task]? = nil
  ) -> Session {
    let date = Date(timeIntervalSince1970: 1_609_459_200)
    return Session(
      id: id,
      status: status,
      expireAt: date,
      abandonAt: date,
      lastActiveAt: date,
      createdAt: date,
      updatedAt: date,
      tasks: tasks
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

  @Test(arguments: PendingSessionLoggingScenario.allCases)
  func shouldLogPendingSessionStatusReturnsExpectedValue(for scenario: PendingSessionLoggingScenario) {
    let logger = SessionStatusLogger()
    let clients = clients(for: scenario)

    let shouldLog = logger.shouldLogPendingSessionStatus(
      previousClient: clients.previous,
      currentClient: clients.current
    )
    #expect(shouldLog == scenario.expected)
  }

  private func clients(
    for scenario: PendingSessionLoggingScenario
  ) -> (previous: Client?, current: Client) {
    switch scenario {
    case .noSessionId:
      let session = createSession(id: "session1", status: .pending)
      let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: nil)
      return (nil, client)
    case .noMatchingSession:
      let session = createSession(id: "session1", status: .pending)
      let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "nonexistent")
      return (nil, client)
    case .nonPendingSession:
      let session = createSession(id: "session1", status: .active)
      let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")
      return (nil, client)
    case .firstClient:
      let session = createSession(id: "session1", status: .pending)
      let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")
      return (nil, client)
    case .noPreviousSession:
      let previous = createClient(id: "client1", sessions: [], lastActiveSessionId: nil)
      let currentSession = createSession(id: "session1", status: .pending)
      let current = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")
      return (previous, current)
    case .sessionIdChanged:
      let previousSession = createSession(id: "session1", status: .pending)
      let previous = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")
      let currentSession = createSession(id: "session2", status: .pending)
      let current = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session2")
      return (previous, current)
    case .sessionStatusChanged:
      let previousSession = createSession(id: "session1", status: .active)
      let previous = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")
      let currentSession = createSession(id: "session1", status: .pending)
      let current = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")
      return (previous, current)
    case .tasksChanged:
      let previousSession = createSession(id: "session1", status: .pending, tasks: [Session.Task(key: "task1")])
      let previous = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")
      let currentSession = createSession(id: "session1", status: .pending, tasks: [Session.Task(key: "task2")])
      let current = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")
      return (previous, current)
    case .tasksChangedFromNilToEmpty:
      let previousSession = createSession(id: "session1", status: .pending, tasks: nil)
      let previous = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")
      let currentSession = createSession(id: "session1", status: .pending, tasks: [])
      let current = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")
      return (previous, current)
    case .tasksChangedFromEmptyToNil:
      let previousSession = createSession(id: "session1", status: .pending, tasks: [])
      let previous = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")
      let currentSession = createSession(id: "session1", status: .pending, tasks: nil)
      let current = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")
      return (previous, current)
    case .noChange:
      let previousSession = createSession(id: "session1", status: .pending, tasks: [Session.Task(key: "task1")])
      let previous = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")
      let currentSession = createSession(id: "session1", status: .pending, tasks: [Session.Task(key: "task1")])
      let current = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")
      return (previous, current)
    case .sameTasksNil:
      let previousSession = createSession(id: "session1", status: .pending, tasks: nil)
      let previous = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")
      let currentSession = createSession(id: "session1", status: .pending, tasks: nil)
      let current = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")
      return (previous, current)
    }
  }
}
