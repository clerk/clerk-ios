//
//  AuthFlowCoordinator+Completion.swift
//  Clerk
//

extension AuthFlowCoordinator {
  /// Claims authentication completion exactly once for work owned by the registered view.
  /// AuthView UI may remain presented after authentication completion is reported.
  mutating func claimAuthenticationCompletion(
    work: AuthFlowWork
  ) -> Bool {
    guard registration?.id == work.ownerId else { return false }

    switch phase {
    case .observing:
      return false
    case .awaiting(var target):
      guard target.canClaimAuthenticationCompletion(for: work) else {
        return false
      }
      target.hasReportedAuthenticationCompletion = true
      phase = .awaiting(target)
    case .presenting(var target, let token):
      guard target.canClaimAuthenticationCompletion(for: work) else {
        return false
      }
      target.hasReportedAuthenticationCompletion = true
      phase = .presenting(target: target, token: token)
    }
    return true
  }
}

extension AuthFlowCoordinator.Target {
  fileprivate func canClaimAuthenticationCompletion(
    for work: AuthFlowWork
  ) -> Bool {
    id == work.id
      && sessionId == work.sessionId
      && canReportAuthenticationCompletion
      && !hasReportedAuthenticationCompletion
  }
}
