//
//  Clerk+AuthFlow.swift
//  Clerk
//

import Foundation

extension Clerk {
  /// Whether authentication and any Clerk-owned post-authentication steps are complete.
  ///
  /// Use this value when choosing between a root authentication view and authenticated content.
  /// It becomes `true` when there is a current user, the current session is active, and a
  /// non-dismissible `AuthView` is no longer completing a post-authentication step.
  public var isAuthFlowComplete: Bool {
    hasActiveUserSession && !authFlowCoordinator.isRootBlocking
  }

  package var authFlowRegistrationId: UUID? {
    authFlowCoordinator.ownerId
  }

  package func authFlowSnapshot(
    for registration: AuthFlowRegistration
  ) -> AuthFlowSnapshot? {
    authFlowCoordinator.snapshot(ownerId: registration.id)
  }

  package func authFlowPresentationIsCurrent(
    _ token: AuthFlowPresentationToken
  ) -> Bool {
    session?.id == token.sessionId
      && authFlowCoordinator.presentationIsCurrent(token)
  }

  package func registerAuthFlow(
    role: AuthFlowRegistration.Role = .root
  ) -> AuthFlowRegistration? {
    guard let registrationId = authFlowCoordinator.register(
      role: role,
      hasActiveUserSession: hasActiveUserSession
    ) else {
      return nil
    }

    return AuthFlowRegistration(id: registrationId) { [weak self] in
      self?.unregisterAuthFlow(registrationId: registrationId)
    }
  }

  package func adoptPendingAuthSession(
    for registration: AuthFlowRegistration,
    session: Session
  ) {
    guard self.session?.id == session.id else { return }
    authFlowCoordinator.adoptPendingSession(
      ownerId: registration.id,
      session: session
    )
  }

  @discardableResult
  package func startAuthFlowPresentation(
    for registration: AuthFlowRegistration,
    work: AuthFlowWork,
    presentation: AuthFlowRegistration.PostAuthPresentation
  ) -> AuthFlowPresentationToken? {
    guard registration.id == work.ownerId,
          session?.id == work.sessionId
    else {
      return nil
    }
    return authFlowCoordinator.startPresentation(
      ownerId: registration.id,
      work: work,
      presentation: presentation
    )
  }

  @discardableResult
  package func finishAuthFlowPresentation(
    _ token: AuthFlowPresentationToken
  ) -> Bool {
    guard session?.id == token.sessionId else { return false }
    // Completing here would mark the flow complete before reconciliation can deliver it.
    return authFlowCoordinator.finishPresentation(token: token)
  }

  @discardableResult
  package func completeAuthFlow(
    _ work: AuthFlowWork
  ) -> Bool {
    guard session?.id == work.sessionId,
          session?.status == .active
    else {
      return false
    }
    return authFlowCoordinator.complete(work: work)
  }

  package func resetAuthFlow(for registration: AuthFlowRegistration) {
    authFlowCoordinator.reset(ownerId: registration.id)
  }

  @discardableResult
  func beginAuthSessionActivation(
    sessionId: String,
    ownerId: UUID?
  ) -> AuthFlowActivationToken? {
    authFlowCoordinator.beginSessionActivation(
      ownerId: ownerId,
      sessionId: sessionId
    )
  }

  @discardableResult
  func beginCompletedAuthSessionActivation(
    sessionId: String,
    flowId: String,
    ownerId: UUID?
  ) -> AuthFlowActivationToken? {
    authFlowCoordinator.beginCompletedSessionActivation(
      ownerId: ownerId,
      sessionId: sessionId,
      flowId: flowId
    )
  }

  func authSessionActivationDidFinish(
    activation: AuthFlowActivationToken
  ) {
    authFlowCoordinator.sessionActivationDidFinish(
      activation: activation,
      client: client
    )
  }

  func resolveAuthFlowCompletion(_ update: AuthFlowIdentityUpdate) {
    authFlowCoordinator.resolveCompletion(update, client: client)
  }

  func resolveSupersededAuthFlowCompletion(
    _ completion: TransferFlowResult,
    ownerId: UUID
  ) {
    resolveAuthFlowCompletion(.resolvingSupersededCompletion(
      completion,
      ownerId: ownerId,
      authoritativeClient: authoritativeClient
    ))
  }

  func resetAuthFlowForReconfiguration() {
    guard let ownerId = authFlowCoordinator.ownerId else { return }
    authFlowCoordinator.reset(ownerId: ownerId)
  }

  private var hasActiveUserSession: Bool {
    user != nil && session?.status == .active
  }

  private func unregisterAuthFlow(registrationId: UUID) {
    authFlowCoordinator.unregister(ownerId: registrationId)
  }
}
