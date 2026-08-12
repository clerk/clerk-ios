//
//  AuthFlowCoordinator.swift
//  Clerk
//

import Foundation

package struct AuthFlowWork: Hashable {
  package let ownerId: UUID
  package let id: UUID
  package let sessionId: String

  package init(ownerId: UUID, id: UUID, sessionId: String) {
    self.ownerId = ownerId
    self.id = id
    self.sessionId = sessionId
  }
}

package struct AuthFlowPresentationToken: Hashable {
  package let work: AuthFlowWork
  package let id: UUID
  package let kind: AuthFlowRegistration.PostAuthPresentation

  package init(
    work: AuthFlowWork,
    id: UUID,
    kind: AuthFlowRegistration.PostAuthPresentation
  ) {
    self.work = work
    self.id = id
    self.kind = kind
  }

  package var sessionId: String {
    work.sessionId
  }
}

struct AuthFlowActivationToken: Hashable {
  let ownerId: UUID
  let id: UUID
  let sessionId: String
}

package struct AuthFlowSnapshot {
  package enum Phase {
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

  package let revision: UInt64
  package let phase: Phase
}

struct AuthFlowCoordinator {
  enum TargetOrigin {
    case external
    case ownedActivation(id: UUID)
    case completed(TransferFlowResult, activationId: UUID?)

    var completion: TransferFlowResult? {
      guard case .completed(let result, _) = self else { return nil }
      return result
    }

    var holdsRoot: Bool {
      if case .external = self { return false }
      return true
    }

    var hasScopedActivation: Bool {
      switch self {
      case .external:
        false
      case .ownedActivation:
        true
      case .completed(_, let activationId):
        activationId != nil
      }
    }

    func owns(_ activation: AuthFlowActivationToken) -> Bool {
      switch self {
      case .external:
        false
      case .ownedActivation(let id):
        id == activation.id
      case .completed(_, let activationId):
        activationId == activation.id
      }
    }

    func resolving(_ activation: AuthFlowActivationToken) -> TargetOrigin? {
      guard owns(activation) else { return nil }
      switch self {
      case .external:
        return nil
      case .ownedActivation:
        return .external
      case .completed(let result, _):
        return .completed(result, activationId: nil)
      }
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

    var holdsRoot: Bool {
      origin.holdsRoot
    }

    var flowId: String? {
      completion?.flowId
    }
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

  var ownerId: UUID? {
    registration?.id
  }

  var isRootBlocking: Bool {
    guard registration?.role == .root else { return false }
    switch phase {
    case .observing:
      return false
    case .awaiting(let target):
      return target.holdsRoot
    case .presenting:
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
    phase = .observing
    advanceRevision()
    return id
  }

  mutating func unregister(ownerId: UUID) {
    guard registration?.id == ownerId else { return }
    registration = nil
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
    token: AuthFlowPresentationToken,
    completesWork: Bool
  ) -> Bool {
    guard registration?.id == token.work.ownerId,
          case .presenting(let target, let currentToken) = phase,
          currentToken == token,
          target.id == token.work.id,
          target.sessionId == token.sessionId
    else {
      return false
    }

    phase = completesWork ? .observing : .awaiting(target)
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
    phase = .observing
    advanceRevision()
    return true
  }

  mutating func reset(ownerId: UUID) {
    guard registration?.id == ownerId else { return }
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
    AuthFlowWork(ownerId: ownerId, id: id, sessionId: sessionId)
  }
}

extension Session {
  var isViableForPostAuth: Bool {
    guard user != nil else { return false }
    return status == .active || status == .pending
  }
}
