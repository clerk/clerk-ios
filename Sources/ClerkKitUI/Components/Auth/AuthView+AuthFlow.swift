//
//  AuthView+AuthFlow.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

extension AuthView {
  enum PostAuthStep: Equatable {
    case biometricCredentialEnrollment
    case sessionTasks
    case complete
  }

  static let postAuthStepOrder: [PostAuthStep] = [
    .biometricCredentialEnrollment,
    .sessionTasks,
    .complete,
  ]

  struct AuthFlowReconciliationID: Equatable {
    let coordinatorOwnerId: UUID?
    let revision: UInt64?
    let sessionId: String?
    let sessionStatus: Session.SessionStatus?
    let pendingSessionTasks: [Session.Task]
  }

  var authFlowSnapshot: AuthFlowSnapshot? {
    guard let authFlowRegistration else { return nil }
    return clerk.authFlowSnapshot(for: authFlowRegistration)
  }

  var authFlowReconciliationID: AuthFlowReconciliationID {
    AuthFlowReconciliationID(
      coordinatorOwnerId: clerk.authFlowRegistrationId,
      revision: authFlowSnapshot?.revision,
      sessionId: clerk.session?.id,
      sessionStatus: clerk.session?.status,
      pendingSessionTasks: clerk.session?.pendingTasks ?? []
    )
  }

  var showDismissButton: Bool {
    isDismissible &&
      !navigation.hasSessionTaskStartInPath &&
      !navigation.hasBiometricCredentialEnrollmentInPath
  }

  @ToolbarContentBuilder
  var dismissToolbarItem: some ToolbarContent {
    if showDismissButton {
      DismissToolbarItem {
        dismissAuthView()
      }
    }
  }

  func resumeAuth(_ result: TransferFlowResult) {
    switch result {
    case .signIn(let signIn):
      navigation.setToStepForStatus(signIn: signIn)
      clerk.setCallbackContinuation(nil)
    case .signUp(let signUp):
      navigation.setToStepForStatus(signUp: signUp)
      clerk.setCallbackContinuation(nil)
    }
  }

  func registerAuthFlowIfNeeded() {
    guard !authFlowRegistrationIsTerminated,
          authFlowRegistration == nil
    else {
      return
    }

    if let conflictingOwnerId = clerk.authFlowRegistrationId {
      if reportedConflictingAuthFlowOwnerId != conflictingOwnerId {
        ClerkLogger.error(
          "Only one AuthView can be mounted at a time for each Clerk instance."
        )
        reportedConflictingAuthFlowOwnerId = conflictingOwnerId
      }
      return
    }

    reportedConflictingAuthFlowOwnerId = nil
    authFlowRegistration = clerk.registerAuthFlow(
      role: isDismissible ? .dismissible : .root
    )
  }

  func adoptPendingSessionIfNeeded(_ session: Session?) {
    guard let owner = authFlowRegistration,
          let session,
          clerk.session?.id == session.id,
          session.status == .pending
    else {
      return
    }
    clerk.adoptPendingAuthSession(for: owner, session: session)
  }

  func reconcileAuthFlow() async {
    guard let owner = authFlowRegistration,
          let snapshot = clerk.authFlowSnapshot(for: owner)
    else {
      return
    }

    switch snapshot.phase {
    case .observing:
      reconcileObserving(owner: owner)
    case .awaiting(let work, let completion):
      navigation.synchronizePostAuthPath(with: work)
      await reconcileAwaitingWork(
        owner: owner,
        work: work,
        completion: completion
      )
    case .presenting(let token, _):
      reconcilePresentation(token)
    }
  }

  func resetAuthFlow(owner: AuthFlowRegistration?) {
    guard let owner else { return }
    clerk.resetAuthFlow(for: owner)
  }

  func dismissAuthView() {
    authFlowRegistrationIsTerminated = true
    authFlowRegistration?.cancel()
    authFlowRegistration = nil
    dismiss()
  }

  private func reconcileObserving(owner: AuthFlowRegistration) {
    guard navigation.presentedAuthFlowToken != nil else {
      adoptPendingSessionIfNeeded(clerk.session)
      return
    }

    if isDismissible {
      dismissAuthView()
    } else if !clerk.isAuthFlowComplete {
      navigation.resetForNewAuthFlow()
      clerk.resetAuthFlow(for: owner)
    }
  }

  private func reconcileAwaitingWork(
    owner: AuthFlowRegistration,
    work: AuthFlowWork,
    completion: TransferFlowResult?
  ) async {
    for step in Self.postAuthStepOrder {
      guard !Task.isCancelled,
            let session = clerk.session,
            session.id == work.sessionId
      else {
        return
      }

      switch step {
      case .biometricCredentialEnrollment:
        guard let completion else { continue }
        let checkpoint = authState.environmentRefreshCheckpoint(for: clerk)
        _ = try? await clerk.ensureEnvironmentRefreshed(after: checkpoint)
        guard !Task.isCancelled else { return }

        if await presentBiometricCredentialEnrollmentIfNeeded(
          after: completion,
          owner: owner,
          work: work
        ) {
          return
        }
      case .sessionTasks:
        if routeToSessionTaskIfNeeded(
          session: session,
          owner: owner,
          work: work
        ) {
          return
        }
      case .complete:
        guard session.status == .active else { continue }
        completeAuthFlow(owner: owner, work: work)
        return
      }
    }
  }

  private func reconcilePresentation(_ token: AuthFlowPresentationToken) {
    guard let session = clerk.session, session.id == token.sessionId else { return }

    switch token.kind {
    case .sessionTasks:
      _ = navigation.routeToSessionTaskStart(session: session, token: token)
    case .biometricCredentialEnrollment:
      navigation.routeToBiometricCredentialEnrollment(
        token: token,
        biometryDisplayName: .current()
      )
    }
  }

  @discardableResult
  private func routeToSessionTaskIfNeeded(
    session: Session,
    owner: AuthFlowRegistration?,
    work: AuthFlowWork
  ) -> Bool {
    guard let owner,
          session.status == .pending,
          !session.pendingTasks.isEmpty,
          let token = clerk.startAuthFlowPresentation(
            for: owner,
            work: work,
            presentation: .sessionTasks
          )
    else {
      return false
    }
    return navigation.routeToSessionTaskStart(session: session, token: token)
  }

  private func completeAuthFlow(
    owner: AuthFlowRegistration,
    work: AuthFlowWork
  ) {
    guard clerk.completeAuthFlow(work) else { return }

    authFlowRegistrationIsTerminated = true
    owner.cancel()
    authFlowRegistration = nil
    onAuthComplete()
    if isDismissible {
      dismiss()
    }
  }

  @discardableResult
  private func presentBiometricCredentialEnrollmentIfNeeded(
    after result: TransferFlowResult,
    owner: AuthFlowRegistration,
    work: AuthFlowWork
  ) async -> Bool {
    guard let context = biometricCredentialEnrollmentContext(
      after: result,
      sessionId: work.sessionId
    ) else {
      return false
    }

    do {
      let availability = try await clerk.biometricCredentials.currentUserAvailability()
      guard enrollmentContextIsCurrent(context, availability: availability),
            let token = clerk.startAuthFlowPresentation(
              for: owner,
              work: work,
              presentation: .biometricCredentialEnrollment
            )
      else {
        return false
      }
      context.promptStore.markPromptSeen(userID: context.userId)
      navigation.routeToBiometricCredentialEnrollment(
        token: token,
        biometryDisplayName: context.biometryDisplayName
      )
      return true
    } catch {
      return false
    }
  }

  private struct BiometricCredentialEnrollmentContext {
    let session: Session
    let userId: String
    let biometryDisplayName: BiometryDisplayName
    let promptStore: BiometricCredentialEnrollmentPromptStore
  }

  private func biometricCredentialEnrollmentContext(
    after result: TransferFlowResult,
    sessionId: String
  ) -> BiometricCredentialEnrollmentContext? {
    guard clerk.callbackContinuation == nil,
          let nativeSettings = clerk.environment?.authConfig.nativeSettings,
          nativeSettings.apiEnabled,
          nativeSettings.biometricSignInEnabled,
          let session = clerk.session,
          session.id == sessionId,
          session.status.allowsBiometricCredentialEnrollment,
          let userId = session.user?.id
    else {
      return nil
    }

    let biometryDisplayName = BiometryDisplayName.current()
    guard biometryDisplayName.isSupported else { return nil }

    let promptStore = BiometricCredentialEnrollmentPromptStore()
    guard result.shouldOfferBiometricCredentialEnrollmentPrompt(
      userID: userId,
      nativeSettings: nativeSettings,
      promptStore: promptStore
    ) else {
      return nil
    }
    return BiometricCredentialEnrollmentContext(
      session: session,
      userId: userId,
      biometryDisplayName: biometryDisplayName,
      promptStore: promptStore
    )
  }

  private func enrollmentContextIsCurrent(
    _ context: BiometricCredentialEnrollmentContext,
    availability: BiometricCredentialAvailability
  ) -> Bool {
    !Task.isCancelled
      && clerk.session?.id == context.session.id
      && clerk.session?.status.allowsBiometricCredentialEnrollment == true
      && clerk.user?.id == context.userId
      && !availability.isAvailable
      && availability.canPromptForEnrollment
  }
}

#endif
