//
//  SessionTransitionTests.swift
//

import Foundation
import Testing

@testable import ClerkKit

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

@Suite
struct SessionTransitionTests {
  // MARK: - nil → new session

  @Test
  func nilToActiveIsActivated() {
    let session = createSession(id: "s1", status: .active)
    let transition = SessionTransition(from: nil, to: session)
    #expect(transition == .activated(session: session))
  }

  @Test
  func nilToPendingIsPending() {
    let session = createSession(id: "s1", status: .pending)
    let transition = SessionTransition(from: nil, to: session)
    #expect(transition == .pending(session: session))
  }

  @Test
  func nilToNilIsUnauthenticated() {
    let transition = SessionTransition(from: nil, to: nil)
    #expect(transition == .unauthenticated)
  }

  // MARK: - session → nil

  @Test
  func activeToNilIsUnauthenticated() {
    let old = createSession(id: "s1", status: .active)
    let transition = SessionTransition(from: old, to: nil)
    #expect(transition == .unauthenticated)
  }

  @Test
  func pendingToNilIsUnauthenticated() {
    let old = createSession(id: "s1", status: .pending)
    let transition = SessionTransition(from: old, to: nil)
    #expect(transition == .unauthenticated)
  }

  // MARK: - active → active

  @Test
  func activeToActiveSameIdIsUpdated() {
    let old = createSession(id: "s1", status: .active)
    let new = createSession(id: "s1", status: .active)
    let transition = SessionTransition(from: old, to: new)
    #expect(transition == .updated(session: new))
  }

  @Test
  func activeToActiveDiffIdIsActivated() {
    let old = createSession(id: "s1", status: .active)
    let new = createSession(id: "s2", status: .active)
    let transition = SessionTransition(from: old, to: new)
    #expect(transition == .activated(session: new))
  }

  // MARK: - pending → active

  @Test
  func pendingToActiveSameIdIsActivated() {
    let old = createSession(id: "s1", status: .pending)
    let new = createSession(id: "s1", status: .active)
    let transition = SessionTransition(from: old, to: new)
    #expect(transition == .activated(session: new))
  }

  @Test
  func pendingToActiveDiffIdIsActivated() {
    let old = createSession(id: "s1", status: .pending)
    let new = createSession(id: "s2", status: .active)
    let transition = SessionTransition(from: old, to: new)
    #expect(transition == .activated(session: new))
  }

  // MARK: - active → pending

  @Test
  func activeToPendingIsPending() {
    let old = createSession(id: "s1", status: .active)
    let new = createSession(id: "s1", status: .pending)
    let transition = SessionTransition(from: old, to: new)
    #expect(transition == .pending(session: new))
  }

  // MARK: - pending → pending

  @Test
  func pendingToPendingSameIdIsUpdated() {
    let old = createSession(id: "s1", status: .pending)
    let new = createSession(id: "s1", status: .pending)
    let transition = SessionTransition(from: old, to: new)
    #expect(transition == .updated(session: new))
  }

  @Test
  func pendingToPendingDiffIdIsPending() {
    let old = createSession(id: "s1", status: .pending)
    let new = createSession(id: "s2", status: .pending)
    let transition = SessionTransition(from: old, to: new)
    #expect(transition == .pending(session: new))
  }

  // MARK: - Terminal statuses

  @Test
  func activeToRevokedIsUnauthenticated() {
    let old = createSession(id: "s1", status: .active)
    let new = createSession(id: "s1", status: .revoked)
    let transition = SessionTransition(from: old, to: new)
    #expect(transition == .unauthenticated)
  }

  @Test
  func nilToRevokedIsUnauthenticated() {
    let new = createSession(id: "s1", status: .revoked)
    let transition = SessionTransition(from: nil, to: new)
    #expect(transition == .unauthenticated)
  }

  @Test
  func activeToAbandonedIsUnauthenticated() {
    let old = createSession(id: "s1", status: .active)
    let new = createSession(id: "s1", status: .abandoned)
    let transition = SessionTransition(from: old, to: new)
    #expect(transition == .unauthenticated)
  }

  // MARK: - session computed property

  @Test
  func sessionPropertyReturnsSessionForActivated() {
    let session = createSession(id: "s1", status: .active)
    let transition = SessionTransition.activated(session: session)
    #expect(transition.session == session)
  }

  @Test
  func sessionPropertyReturnsSessionForPending() {
    let session = createSession(id: "s1", status: .pending)
    let transition = SessionTransition.pending(session: session)
    #expect(transition.session == session)
  }

  @Test
  func sessionPropertyReturnsSessionForUpdated() {
    let session = createSession(id: "s1", status: .active)
    let transition = SessionTransition.updated(session: session)
    #expect(transition.session == session)
  }

  @Test
  func sessionPropertyReturnsNilForUnauthenticated() {
    let transition = SessionTransition.unauthenticated
    #expect(transition.session == nil)
  }
}
