//
//  SessionUtilsTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import Foundation
import Testing

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

  // MARK: - Client.currentSession Tests

  @Test
  func currentSession_NoLastActiveSessionId() {
    let session = createSession(id: "session1", status: .active)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: nil)

    #expect(client.currentSession == nil)
  }

  @Test
  func currentSession_NoMatchingSession() {
    let session = createSession(id: "session1", status: .active)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "nonexistent")

    #expect(client.currentSession == nil)
  }

  @Test
  func currentSession_ReturnsPendingSession() {
    let session = createSession(id: "session1", status: .pending)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")

    #expect(client.currentSession?.id == "session1")
  }

  @Test
  func currentSession_ReturnsSession() {
    let session = createSession(id: "session1", status: .active)
    let client = createClient(id: "client1", sessions: [session], lastActiveSessionId: "session1")

    let currentSession = client.currentSession
    #expect(currentSession != nil)
    #expect(currentSession?.id == "session1")
  }

  @Test
  func currentSession_ReturnsCorrectSessionFromMultipleSessions() {
    let session1 = createSession(id: "session1", status: .active)
    let session2 = createSession(id: "session2", status: .active)
    let session3 = createSession(id: "session3", status: .pending)
    let client = createClient(
      id: "client1",
      sessions: [session1, session2, session3],
      lastActiveSessionId: "session2"
    )

    let currentSession = client.currentSession
    #expect(currentSession != nil)
    #expect(currentSession?.id == "session2")
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

    // When session status changes, the current session should be considered changed.
    let changed = SessionUtils.sessionChanged(previousClient: previousClient, currentClient: currentClient)
    #expect(changed == true)
  }
}
