//
//  AuthFlowCoordinator+Identity.swift
//  Clerk
//

import Foundation

extension AuthFlowCoordinator {
  mutating func applyIdentity(
    previousClient: Client?,
    client: Client?,
    update: AuthFlowIdentityUpdate
  ) {
    guard let registration else { return }

    var phaseChanged = false
    var acceptedCompletion = false
    if let completion = update.completion,
       completion.ownerId == registration.id
    {
      phaseChanged = apply(completion, client: client)
      if case .accepted = completion {
        acceptedCompletion = true
      }
    }

    let shouldReplacePendingWork = update.authoritativeIdentityChanged
      && !acceptedCompletion
    phaseChanged = reconcileTarget(
      previousClient: previousClient,
      client: client,
      authoritativeIdentityChanged: shouldReplacePendingWork
    ) || phaseChanged
    if phaseChanged {
      advanceRevision()
    }
  }

  mutating func resolveCompletion(
    _ update: AuthFlowIdentityUpdate,
    client: Client?
  ) {
    guard let registration,
          let completion = update.completion,
          completion.ownerId == registration.id
    else {
      return
    }

    if apply(completion, client: client) {
      advanceRevision()
    }
  }

  mutating func beginSessionActivation(
    ownerId: UUID?,
    sessionId: String
  ) -> AuthFlowActivationToken? {
    guard let ownerId, registration?.id == ownerId else { return nil }
    let activation = AuthFlowActivationToken(
      ownerId: ownerId,
      id: UUID(),
      sessionId: sessionId
    )

    if let target = currentTarget, target.sessionId == sessionId {
      guard target.completion == nil else { return nil }
      _ = mutateCurrentTarget {
        $0.origin = .ownedActivation(id: activation.id)
        $0.canReportAuthenticationCompletion = true
      }
    } else {
      phase = .awaiting(Target(
        id: UUID(),
        sessionId: sessionId,
        origin: .ownedActivation(id: activation.id),
        canReportAuthenticationCompletion: true
      ))
    }
    advanceRevision()
    return activation
  }

  mutating func beginCompletedSessionActivation(
    ownerId: UUID?,
    sessionId: String,
    flowId: String
  ) -> AuthFlowActivationToken? {
    guard let ownerId, registration?.id == ownerId else { return nil }
    let activation = AuthFlowActivationToken(
      ownerId: ownerId,
      id: UUID(),
      sessionId: sessionId
    )

    guard let target = currentTarget,
          target.sessionId == sessionId,
          let completion = target.completion,
          completion.flowId == flowId
    else {
      return nil
    }
    _ = mutateCurrentTarget {
      $0.origin = .completed(
        completion,
        activationId: activation.id
      )
    }
    advanceRevision()
    return activation
  }

  mutating func sessionActivationDidFinish(
    activation: AuthFlowActivationToken,
    client: Client?
  ) {
    guard registration?.id == activation.ownerId,
          let target = currentTarget,
          target.origin.owns(activation)
    else {
      return
    }

    if currentSessionMatches(activation, client: client),
       let resolvedOrigin = target.origin.resolving(activation)
    {
      _ = mutateCurrentTarget { $0.origin = resolvedOrigin }
    } else {
      _ = adoptCurrentSession(from: client)
    }
    advanceRevision()
  }

  private mutating func apply(
    _ completion: AuthFlowIdentityUpdate.Completion,
    client: Client?
  ) -> Bool {
    switch completion {
    case .accepted(let result, _):
      applyAcceptedCompletion(result, client: client)
    case .superseded(let flowId, _):
      applySupersededCompletion(flowId: flowId, client: client)
    }
  }

  private mutating func applyAcceptedCompletion(
    _ result: TransferFlowResult,
    client: Client?
  ) -> Bool {
    guard let sessionId = result.createdSessionId
      ?? client?.currentSession?.id
    else {
      if case .observing = phase { return false }
      phase = .observing
      return true
    }

    if case .presenting(var target, let token) = phase,
       target.sessionId == sessionId
    {
      guard target.completion == nil else { return false }
      target.origin = .completed(result, activationId: nil)
      target.canReportAuthenticationCompletion = true
      phase = .presenting(target: target, token: token)
      return true
    }

    if case .awaiting(var target) = phase,
       target.sessionId == sessionId
    {
      if target.completion == nil {
        target.origin = .completed(result, activationId: nil)
        target.canReportAuthenticationCompletion = true
        phase = .awaiting(target)
        return true
      }
      if target.flowId == result.flowId {
        return false
      }
    }

    phase = .awaiting(Target(
      id: UUID(),
      sessionId: sessionId,
      origin: .completed(result, activationId: nil),
      canReportAuthenticationCompletion: true
    ))
    return true
  }

  private mutating func applySupersededCompletion(
    flowId: String,
    client: Client?
  ) -> Bool {
    switch phase {
    case .observing:
      return adoptCurrentSession(from: client)
    case .presenting:
      return false
    case .awaiting(let target):
      switch target.origin {
      case .external:
        return adoptCurrentSession(from: client)
      case .ownedActivation:
        return false
      case .completed:
        guard target.flowId == flowId else { return false }
        guard !targetIsViable(target, in: client) else { return false }
        return adoptCurrentSession(from: client)
      }
    }
  }

  private mutating func reconcileTarget(
    previousClient: Client?,
    client: Client?,
    authoritativeIdentityChanged: Bool
  ) -> Bool {
    switch phase {
    case .observing:
      reconcileObserving(previousClient: previousClient, client: client)
    case .awaiting(let target):
      reconcileAwaiting(
        target,
        previousClient: previousClient,
        client: client,
        authoritativeIdentityChanged: authoritativeIdentityChanged
      )
    case .presenting(let target, _):
      reconcilePresenting(target, client: client)
    }
  }

  private mutating func reconcileObserving(
    previousClient: Client?,
    client: Client?
  ) -> Bool {
    guard let currentSession = client?.currentSession,
          currentSession.isViableForPostAuth,
          Self.didActivateDifferentSession(
            previous: previousClient?.currentSession,
            current: currentSession
          )
    else {
      return false
    }
    phase = .awaiting(target(
      for: currentSession,
      canReportAuthenticationCompletion: false
    ))
    return true
  }

  private mutating func reconcileAwaiting(
    _ target: Target,
    previousClient: Client?,
    client: Client?,
    authoritativeIdentityChanged: Bool
  ) -> Bool {
    guard let currentSession = client?.currentSession else {
      guard !targetIsViable(target, in: client) else { return false }
      phase = .observing
      return true
    }

    if currentSession.id == target.sessionId,
       currentSession.isViableForPostAuth
    {
      return false
    }

    let targetIsViable = targetIsViable(target, in: client)
    if target.origin.hasScopedActivation, targetIsViable {
      return false
    }

    let currentSessionChanged = previousClient?.currentSession?.id != currentSession.id
    guard targetIsViable,
          !authoritativeIdentityChanged,
          !currentSessionChanged
    else {
      return adoptCurrentSession(from: client)
    }
    return false
  }

  private mutating func reconcilePresenting(
    _ target: Target,
    client: Client?
  ) -> Bool {
    if let currentSession = client?.currentSession,
       currentSession.id == target.sessionId,
       currentSession.isViableForPostAuth
    {
      return false
    }
    if target.origin.hasScopedActivation, targetIsViable(target, in: client) {
      return false
    }
    return adoptCurrentSession(from: client)
  }

  private mutating func adoptCurrentSession(from client: Client?) -> Bool {
    guard let currentSession = client?.currentSession,
          currentSession.isViableForPostAuth
    else {
      if case .observing = phase { return false }
      phase = .observing
      return true
    }
    if currentTarget?.sessionId == currentSession.id {
      return false
    }
    phase = .awaiting(target(
      for: currentSession,
      canReportAuthenticationCompletion: false
    ))
    return true
  }

  private func targetIsViable(_ target: Target, in client: Client?) -> Bool {
    client?.sessions.contains {
      $0.id == target.sessionId && $0.isViableForPostAuth
    } == true
  }

  private func currentSessionMatches(
    _ activation: AuthFlowActivationToken,
    client: Client?
  ) -> Bool {
    guard let currentSession = client?.currentSession else { return false }
    return currentSession.id == activation.sessionId
      && currentSession.isViableForPostAuth
  }

  private static func didActivateDifferentSession(
    previous: Session?,
    current: Session
  ) -> Bool {
    previous?.id != current.id
      || previous?.isViableForPostAuth != true
      || (previous?.status != .active && current.status == .active)
  }

  private var currentTarget: Target? {
    switch phase {
    case .observing:
      nil
    case .awaiting(let target), .presenting(let target, _):
      target
    }
  }

  @discardableResult
  private mutating func mutateCurrentTarget(
    _ mutation: (inout Target) -> Void
  ) -> Bool {
    switch phase {
    case .observing:
      return false
    case .awaiting(var target):
      mutation(&target)
      phase = .awaiting(target)
    case .presenting(var target, let token):
      mutation(&target)
      phase = .presenting(target: target, token: token)
    }
    return true
  }
}
