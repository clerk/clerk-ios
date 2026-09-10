//
//  AuthFlowCoordinator.swift
//  Clerk
//

import ClerkKit
import Foundation

struct AuthFlowWork: Hashable {
  let ownerId: UUID
  let id: UUID
  let sessionId: String
}

struct AuthFlowPresentationToken: Hashable {
  let work: AuthFlowWork
  let id: UUID
  let kind: AuthFlowRegistration.PostAuthPresentation

  var sessionId: String {
    work.sessionId
  }
}

struct AuthFlowSnapshot {
  enum Phase {
    case observing
    case awaiting(
      work: AuthFlowWork,
      completion: TransferFlowResult?
    )
    case presenting(
      token: AuthFlowPresentationToken,
      completion: TransferFlowResult?
    )
  }

  let revision: UInt64
  let phase: Phase
}

@MainActor struct AuthFlowCoordinator {
  enum TargetOrigin {
    case external
    case completed(TransferFlowResult)

    var completion: TransferFlowResult? {
      guard case .completed(let result) = self else { return nil }
      return result
    }
  }

  struct Registration {
    let id: UUID
    let role: AuthFlowRegistration.Role
  }

  struct Target {
    let id: UUID
    let sessionId: String
    var origin: TargetOrigin

    /// Whether this work has already presented or moved past enrollment.
    var hasResolvedEnrollmentStep = false

    var completion: TransferFlowResult? {
      origin.completion
    }

    var enrollmentCompletion: TransferFlowResult? {
      hasResolvedEnrollmentStep ? nil : completion
    }

    /// Generated resources mutate in place when a new attempt replaces the old one.
    var flowId: String?
  }

  enum Phase {
    case observing
    case awaiting(Target)
    case presenting(
      target: Target,
      token: AuthFlowPresentationToken
    )

    func snapshot(ownerId: UUID) -> AuthFlowSnapshot.Phase {
      switch self {
      case .observing:
        .observing
      case .awaiting(let target):
        .awaiting(
          work: target.work(ownerId: ownerId),
          completion: target.enrollmentCompletion
        )
      case .presenting(let target, let token):
        .presenting(
          token: token,
          completion: target.completion
        )
      }
    }
  }

  var registration: Registration?
  var phase = Phase.observing
  var revision: UInt64 = 0
  var completedSessionId: String?

  var ownerId: UUID? {
    registration?.id
  }

  var isRootBlocking: Bool {
    guard registration?.role == .root else { return false }
    switch phase {
    case .observing:
      return completedSessionId == nil
    case .awaiting, .presenting:
      return true
    }
  }

  mutating func register(
    role: AuthFlowRegistration.Role,
    hasActiveUserSession: Bool
  ) -> UUID? {
    guard registration == nil else { return nil }
    guard role == .dismissible || !hasActiveUserSession else { return nil }

    let id = UUID()
    registration = Registration(id: id, role: role)
    completedSessionId = nil
    phase = .observing
    advanceRevision()
    return id
  }

  mutating func unregister(ownerId: UUID) {
    guard registration?.id == ownerId else { return }
    registration = nil
    completedSessionId = nil
    phase = .observing
    advanceRevision()
  }

  func snapshot(ownerId: UUID) -> AuthFlowSnapshot? {
    guard registration?.id == ownerId else { return nil }
    return AuthFlowSnapshot(
      revision: revision,
      phase: phase.snapshot(ownerId: ownerId)
    )
  }

  func presentationIsCurrent(_ token: AuthFlowPresentationToken) -> Bool {
    guard registration?.id == token.work.ownerId,
          case .presenting(let target, let currentToken) = phase
    else {
      return false
    }
    return currentToken == token
      && target.id == token.work.id
      && target.sessionId == token.sessionId
  }

  mutating func adoptPendingSession(
    ownerId: UUID,
    session: Session
  ) {
    guard registration?.id == ownerId,
          session.status == .pending
    else {
      return
    }

    switch phase {
    case .observing:
      completedSessionId = nil
      phase = .awaiting(externalTarget(for: session))
      advanceRevision()
    case .awaiting, .presenting:
      break
    }
  }

  mutating func startPresentation(
    ownerId: UUID,
    work: AuthFlowWork,
    presentation: AuthFlowRegistration.PostAuthPresentation
  ) -> AuthFlowPresentationToken? {
    guard registration?.id == ownerId,
          work.ownerId == ownerId
    else {
      return nil
    }

    guard case .awaiting(var target) = phase else {
      return nil
    }

    guard target.id == work.id,
          target.sessionId == work.sessionId
    else {
      return nil
    }

    let token = AuthFlowPresentationToken(
      work: work,
      id: UUID(),
      kind: presentation
    )
    // Enrollment is the first optional post-auth step; never insert it behind another screen.
    target.hasResolvedEnrollmentStep = true
    phase = .presenting(target: target, token: token)
    advanceRevision()
    return token
  }

  mutating func finishPresentation(
    token: AuthFlowPresentationToken
  ) -> Bool {
    guard registration?.id == token.work.ownerId,
          case .presenting(let target, let currentToken) = phase,
          currentToken == token,
          target.id == token.work.id,
          target.sessionId == token.sessionId
    else {
      return false
    }

    phase = .awaiting(target)
    advanceRevision()
    return true
  }

  mutating func complete(
    work: AuthFlowWork
  ) -> Bool {
    guard registration?.id == work.ownerId,
          case .awaiting(let target) = phase,
          target.id == work.id,
          target.sessionId == work.sessionId
    else {
      return false
    }
    completedSessionId = work.sessionId
    phase = .observing
    advanceRevision()
    return true
  }

  mutating func reset(ownerId: UUID) {
    guard registration?.id == ownerId else { return }
    completedSessionId = nil
    phase = .observing
    advanceRevision()
  }

  func externalTarget(for session: Session) -> Target {
    Target(
      id: UUID(),
      sessionId: session.id,
      origin: .external
    )
  }

  mutating func advanceRevision() {
    revision &+= 1
  }
}

extension AuthFlowCoordinator.Target {
  fileprivate func work(ownerId: UUID) -> AuthFlowWork {
    AuthFlowWork(
      ownerId: ownerId,
      id: id,
      sessionId: sessionId
    )
  }
}

extension Session {
  var isViableForPostAuth: Bool {
    guard user != nil else { return false }
    return status == .active || status == .pending
  }
}
