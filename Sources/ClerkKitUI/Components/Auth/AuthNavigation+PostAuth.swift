//
//  AuthNavigation+PostAuth.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit

extension AuthNavigation {
  func nextPendingSessionTask(from session: Session?) -> Session.Task? {
    session?.pendingTasks.first
  }

  var presentedAuthFlowToken: AuthFlowPresentationToken? {
    path.reversed().compactMap(\.authFlowPresentationToken).first
  }

  @discardableResult
  func routeToSessionTaskStart(
    session: Session,
    token: AuthFlowPresentationToken
  ) -> Bool {
    guard token.kind == .sessionTasks,
          session.id == token.sessionId
    else {
      return false
    }
    if presentedAuthFlowToken == token {
      return true
    }

    synchronizePostAuthPath(with: token)
    guard let task = nextPendingSessionTask(from: session) else { return false }
    path.append(.sessionTaskStart(task: task, token: token))
    return true
  }

  @discardableResult
  func appendPostAuthDestination(_ destination: AuthView.Destination) -> Bool {
    guard let token = destination.authFlowPresentationToken,
          token.kind == .sessionTasks,
          presentedAuthFlowToken == token
    else {
      return false
    }
    path.append(destination)
    return true
  }

  func routeToBiometricCredentialEnrollment(
    token: AuthFlowPresentationToken,
    biometryDisplayName: BiometryDisplayName
  ) {
    guard token.kind == .biometricCredentialEnrollment else { return }
    if presentedAuthFlowToken == token {
      return
    }

    synchronizePostAuthPath(with: token)
    path.append(.biometricCredentialEnrollment(
      biometryDisplayName: biometryDisplayName,
      token: token
    ))
  }

  func synchronizePostAuthPath(with token: AuthFlowPresentationToken?) {
    guard let presentedToken = presentedAuthFlowToken else { return }
    guard presentedToken != token else { return }
    if let token, presentedToken.work == token.work {
      return
    }
    clearPostAuthPath()
  }

  func synchronizePostAuthPath(with work: AuthFlowWork) {
    guard let presentedToken = presentedAuthFlowToken,
          presentedToken.work != work
    else {
      return
    }
    clearPostAuthPath()
  }

  func resetForNewAuthFlow() {
    path = []
  }

  var hasSessionTaskStartInPath: Bool {
    path.contains { destination in
      if case .sessionTaskStart = destination {
        true
      } else {
        false
      }
    }
  }

  var hasBiometricCredentialEnrollmentInPath: Bool {
    path.contains { destination in
      if case .biometricCredentialEnrollment = destination {
        true
      } else {
        false
      }
    }
  }

  func clearPostAuthPath() {
    guard let firstPostAuthIndex = path.firstIndex(where: {
      $0.authFlowPresentationToken != nil
    }) else {
      return
    }
    path.removeSubrange(firstPostAuthIndex...)
  }
}

#endif
