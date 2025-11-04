//
//  SessionStatusLoggerTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct SessionStatusLoggerTests {

  func createSession(
    id: String,
    status: Session.SessionStatus,
    tasks: [Session.Task]? = nil
  ) -> Session {
    let date = Date(timeIntervalSince1970: 1609459200)
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
    return Client(
      id: id,
      sessions: sessions,
      lastActiveSessionId: lastActiveSessionId,
      updatedAt: Date(timeIntervalSince1970: 1609459200)
    )
  }

  @Test
  func testShouldLogPendingSessionStatus_NoSessionId() {
    let logger = SessionStatusLogger()
    let session = createSession(id: "session1", status: .pending)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: nil)

    let shouldLog = logger.shouldLogPendingSessionStatus(previousClient: nil, currentClient: client)
    #expect(shouldLog == false)
  }

  @Test
  func testShouldLogPendingSessionStatus_NoMatchingSession() {
    let logger = SessionStatusLogger()
    let session = createSession(id: "session1", status: .pending)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "nonexistent")

    let shouldLog = logger.shouldLogPendingSessionStatus(previousClient: nil, currentClient: client)
    #expect(shouldLog == false)
  }

  @Test
  func testShouldLogPendingSessionStatus_NonPendingSession() {
    let logger = SessionStatusLogger()
    let session = createSession(id: "session1", status: .active)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")

    let shouldLog = logger.shouldLogPendingSessionStatus(previousClient: nil, currentClient: client)
    #expect(shouldLog == false)
  }

  @Test
  func testShouldLogPendingSessionStatus_FirstClient() {
    let logger = SessionStatusLogger()
    let session = createSession(id: "session1", status: .pending)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")

    let shouldLog = logger.shouldLogPendingSessionStatus(previousClient: nil, currentClient: client)
    #expect(shouldLog == true)
  }

  @Test
  func testShouldLogPendingSessionStatus_NoPreviousSession() {
    let logger = SessionStatusLogger()
    let previousClient = createClient(id: "client1", sessions: [], lastActiveSessionId: nil)
    let currentSession = createSession(id: "session1", status: .pending)
    let currentClient = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")

    let shouldLog = logger.shouldLogPendingSessionStatus(previousClient: previousClient, currentClient: currentClient)
    #expect(shouldLog == true)
  }

  @Test
  func testShouldLogPendingSessionStatus_SessionIdChanged() {
    let logger = SessionStatusLogger()
    let previousSession = createSession(id: "session1", status: .pending)
    let previousClient = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")

    let currentSession = createSession(id: "session2", status: .pending)
    let currentClient = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session2")

    let shouldLog = logger.shouldLogPendingSessionStatus(previousClient: previousClient, currentClient: currentClient)
    #expect(shouldLog == true)
  }

  @Test
  func testShouldLogPendingSessionStatus_SessionStatusChanged() {
    let logger = SessionStatusLogger()
    let previousSession = createSession(id: "session1", status: .active)
    let previousClient = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")

    let currentSession = createSession(id: "session1", status: .pending)
    let currentClient = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")

    let shouldLog = logger.shouldLogPendingSessionStatus(previousClient: previousClient, currentClient: currentClient)
    #expect(shouldLog == true)
  }

  @Test
  func testShouldLogPendingSessionStatus_TasksChanged() {
    let logger = SessionStatusLogger()
    let previousSession = createSession(id: "session1", status: .pending, tasks: [Session.Task(key: "task1")])
    let previousClient = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")

    let currentSession = createSession(id: "session1", status: .pending, tasks: [Session.Task(key: "task2")])
    let currentClient = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")

    let shouldLog = logger.shouldLogPendingSessionStatus(previousClient: previousClient, currentClient: currentClient)
    #expect(shouldLog == true)
  }

  @Test
  func testShouldLogPendingSessionStatus_TasksChangedFromNilToEmpty() {
    let logger = SessionStatusLogger()
    let previousSession = createSession(id: "session1", status: .pending, tasks: nil)
    let previousClient = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")

    let currentSession = createSession(id: "session1", status: .pending, tasks: [])
    let currentClient = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")

    let shouldLog = logger.shouldLogPendingSessionStatus(previousClient: previousClient, currentClient: currentClient)
    // nil and [] are considered equal in the comparison, so should not log
    #expect(shouldLog == false)
  }

  @Test
  func testShouldLogPendingSessionStatus_TasksChangedFromEmptyToNil() {
    let logger = SessionStatusLogger()
    let previousSession = createSession(id: "session1", status: .pending, tasks: [])
    let previousClient = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")

    let currentSession = createSession(id: "session1", status: .pending, tasks: nil)
    let currentClient = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")

    let shouldLog = logger.shouldLogPendingSessionStatus(previousClient: previousClient, currentClient: currentClient)
    // nil and [] are considered equal in the comparison, so should not log
    #expect(shouldLog == false)
  }

  @Test
  func testShouldLogPendingSessionStatus_NoChange() {
    let logger = SessionStatusLogger()
    let previousSession = createSession(id: "session1", status: .pending, tasks: [Session.Task(key: "task1")])
    let previousClient = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")

    let currentSession = createSession(id: "session1", status: .pending, tasks: [Session.Task(key: "task1")])
    let currentClient = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")

    let shouldLog = logger.shouldLogPendingSessionStatus(previousClient: previousClient, currentClient: currentClient)
    #expect(shouldLog == false)
  }

  @Test
  func testShouldLogPendingSessionStatus_SameTasksNil() {
    let logger = SessionStatusLogger()
    let previousSession = createSession(id: "session1", status: .pending, tasks: nil)
    let previousClient = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")

    let currentSession = createSession(id: "session1", status: .pending, tasks: nil)
    let currentClient = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")

    let shouldLog = logger.shouldLogPendingSessionStatus(previousClient: previousClient, currentClient: currentClient)
    #expect(shouldLog == false)
  }
}
