//
//  SessionUtilsTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct SessionUtilsTests {
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

  // MARK: - Client.activeSession Tests

  @Test
  func activeSession_NoLastActiveSessionId() {
    let session = createSession(id: "session1", status: .active)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: nil)

    #expect(client.activeSession == nil)
  }

  @Test
  func activeSession_NoMatchingSession() {
    let session = createSession(id: "session1", status: .active)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "nonexistent")

    #expect(client.activeSession == nil)
  }

  @Test
  func activeSession_SessionNotActive() {
    let session = createSession(id: "session1", status: .pending)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")

    #expect(client.activeSession == nil)
  }

  @Test
  func activeSession_ReturnsActiveSession() {
    let session = createSession(id: "session1", status: .active)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")

    let activeSession = client.activeSession
    #expect(activeSession != nil)
    #expect(activeSession?.id == "session1")
  }

  @Test
  func activeSession_ReturnsCorrectSessionFromMultipleSessions() {
    let session1 = createSession(id: "session1", status: .active)
    let session2 = createSession(id: "session2", status: .active)
    let session3 = createSession(id: "session3", status: .pending)
    let client = createClient(
      id: "client1",
      sessions: [session1, session2, session3],
      lastActiveSessionId: "session2"
    )

    let activeSession = client.activeSession
    #expect(activeSession != nil)
    #expect(activeSession?.id == "session2")
  }

  // MARK: - SessionUtils.activeSession(from:) Tests

  @Test
  func activeSessionFrom_NilClient() {
    let session = SessionUtils.activeSession(from: nil)
    #expect(session == nil)
  }

  @Test
  func activeSessionFrom_ClientWithActiveSession() {
    let session = createSession(id: "session1", status: .active)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")

    let activeSession = SessionUtils.activeSession(from: client)
    #expect(activeSession != nil)
    #expect(activeSession?.id == "session1")
  }

  @Test
  func activeSessionFrom_ClientWithoutActiveSession() {
    let session = createSession(id: "session1", status: .pending)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")

    let activeSession = SessionUtils.activeSession(from: client)
    #expect(activeSession == nil)
  }

  // MARK: - SessionUtils.sessionChanged Tests

  @Test
  func sessionChanged_NilToNil() {
    let changed = SessionUtils.sessionChanged(previousClient: nil, currentClient: nil)
    #expect(changed == false)
  }

  @Test
  func sessionChanged_NilToSession() {
    let session = createSession(id: "session1", status: .active)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")

    let changed = SessionUtils.sessionChanged(previousClient: nil, currentClient: client)
    #expect(changed == true)
  }

  @Test
  func sessionChanged_SessionToNil() {
    let session = createSession(id: "session1", status: .active)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")

    let changed = SessionUtils.sessionChanged(previousClient: client, currentClient: nil)
    #expect(changed == true)
  }

  @Test
  func sessionChanged_SameSessionUnchanged() {
    let session = createSession(id: "session1", status: .active)
    let previousClient = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")
    let currentClient = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")

    let changed = SessionUtils.sessionChanged(previousClient: previousClient, currentClient: currentClient)
    #expect(changed == false)
  }

  @Test
  func sessionChanged_DifferentSessionId() {
    let session1 = createSession(id: "session1", status: .active)
    let session2 = createSession(id: "session2", status: .active)
    let previousClient = createClient(id: "client1", sessions: [session1], lastActiveSessionId: "session1")
    let currentClient = createClient(id: "client1", sessions: [session2], lastActiveSessionId: "session2")

    let changed = SessionUtils.sessionChanged(previousClient: previousClient, currentClient: currentClient)
    #expect(changed == true)
  }

  @Test
  func sessionChanged_SameSessionIdDifferentStatus() {
    let previousSession = createSession(id: "session1", status: .active)
    let currentSession = createSession(id: "session1", status: .pending)
    let previousClient = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")
    let currentClient = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")

    let changed = SessionUtils.sessionChanged(previousClient: previousClient, currentClient: currentClient)
    #expect(changed == true)
  }

  @Test
  func sessionChanged_SameSessionIdDifferentUpdatedAt() {
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
    let previousClient = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")
    let currentClient = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")

    let changed = SessionUtils.sessionChanged(previousClient: previousClient, currentClient: currentClient)
    #expect(changed == true)
  }

  @Test
  func sessionChanged_NoSessionToNoSession() {
    let previousClient = createClient(id: "client1", sessions: [], lastActiveSessionId: nil)
    let currentClient = createClient(id: "client1", sessions: [], lastActiveSessionId: nil)

    let changed = SessionUtils.sessionChanged(previousClient: previousClient, currentClient: currentClient)
    #expect(changed == false)
  }

  @Test
  func sessionChanged_NoSessionToSession() {
    let session = createSession(id: "session1", status: .active)
    let previousClient = createClient(id: "client1", sessions: [], lastActiveSessionId: nil)
    let currentClient = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")

    let changed = SessionUtils.sessionChanged(previousClient: previousClient, currentClient: currentClient)
    #expect(changed == true)
  }

  @Test
  func sessionChanged_SessionToNoSession() {
    let session = createSession(id: "session1", status: .active)
    let previousClient = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")
    let currentClient = createClient(id: "client1", sessions: [], lastActiveSessionId: nil)

    let changed = SessionUtils.sessionChanged(previousClient: previousClient, currentClient: currentClient)
    #expect(changed == true)
  }

  @Test
  func sessionChanged_SessionBecomesInactive() {
    let previousSession = createSession(id: "session1", status: .active)
    let currentSession = createSession(id: "session1", status: .expired)
    let previousClient = createClient(id: "client1", sessions: [previousSession], lastActiveSessionId: "session1")
    let currentClient = createClient(id: "client1", sessions: [currentSession], lastActiveSessionId: "session1")

    // When session becomes inactive, it's no longer in activeSessions, so activeSession becomes nil
    let changed = SessionUtils.sessionChanged(previousClient: previousClient, currentClient: currentClient)
    #expect(changed == true)
  }
}
