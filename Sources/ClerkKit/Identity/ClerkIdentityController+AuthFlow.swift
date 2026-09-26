//
//  ClerkIdentityController+AuthFlow.swift
//  Clerk
//

import Foundation

/// Reports sign-in and sign-up completions carried by identity changes.
extension ClerkIdentityController {
  func authFlowUpdate(
    for completedAuthFlow: TransferFlowResult?,
    ownerId: UUID?
  ) -> AuthFlowIdentityUpdate {
    guard let completedAuthFlow, let ownerId else { return .ordinary }
    return .completionAccepted(completedAuthFlow, ownerId: ownerId)
  }

  func emitAcceptedAuthCompletion(_ completedAuthFlow: TransferFlowResult?, clerk: Clerk) {
    switch completedAuthFlow {
    case .signIn(let signIn):
      clerk.auth.send(.signInCompleted(signIn: signIn))
    case .signUp(let signUp):
      clerk.auth.send(.signUpCompleted(signUp: signUp))
    case nil:
      break
    }
  }

  /// A rejected response still completes its flow when a newer response already made its session current.
  func resolveRejectedResponseAuthFlow(_ completedAuthFlow: TransferFlowResult?, ownerId: UUID?) {
    guard let clerk,
          resolveSupersededAuthFlowCompletion(completedAuthFlow, ownerId: ownerId) == .accepted
    else {
      return
    }
    emitAcceptedAuthCompletion(completedAuthFlow, clerk: clerk)
  }

  /// Resolves a flow whose response was not applied, and reports whether its session is current anyway.
  @discardableResult
  func resolveSupersededAuthFlowCompletion(
    _ completedAuthFlow: TransferFlowResult?,
    ownerId: UUID?
  ) -> AuthFlowCompletionDisposition {
    guard let clerk, let completedAuthFlow else { return .absent }
    let disposition = AuthFlowIdentityUpdate.completionDisposition(
      for: completedAuthFlow,
      authoritativeClient: clerk.client
    )
    if let ownerId {
      clerk.resolveSupersededAuthFlowCompletion(completedAuthFlow, ownerId: ownerId)
    }
    return disposition
  }
}
