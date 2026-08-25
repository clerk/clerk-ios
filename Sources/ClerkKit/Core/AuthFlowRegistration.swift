//
//  AuthFlowRegistration.swift
//  Clerk
//

import Foundation

struct AuthFlowIdentityUpdate {
  enum Completion {
    case accepted(TransferFlowResult, ownerId: UUID)
    case superseded(flowId: String, ownerId: UUID)

    var ownerId: UUID {
      switch self {
      case .accepted(_, let ownerId), .superseded(_, let ownerId):
        ownerId
      }
    }
  }

  let authoritativeIdentityChanged: Bool
  let completion: Completion?

  static let ordinary = AuthFlowIdentityUpdate(
    authoritativeIdentityChanged: false,
    completion: nil
  )

  static let authoritativeIdentityChanged = AuthFlowIdentityUpdate(
    authoritativeIdentityChanged: true,
    completion: nil
  )

  static func completionAccepted(
    _ completion: TransferFlowResult,
    ownerId: UUID,
    authoritativeIdentityChanged: Bool = false
  ) -> AuthFlowIdentityUpdate {
    AuthFlowIdentityUpdate(
      authoritativeIdentityChanged: authoritativeIdentityChanged,
      completion: .accepted(completion, ownerId: ownerId)
    )
  }

  static func resolvingSupersededCompletion(
    _ completion: TransferFlowResult,
    ownerId: UUID,
    authoritativeClient: Client?,
    authoritativeIdentityChanged: Bool = false
  ) -> AuthFlowIdentityUpdate {
    if let createdSessionId = completion.createdSessionId,
       let currentSession = authoritativeClient?.currentSession,
       currentSession.id == createdSessionId,
       currentSession.isViableForPostAuth
    {
      return .completionAccepted(
        completion,
        ownerId: ownerId,
        authoritativeIdentityChanged: authoritativeIdentityChanged
      )
    }

    return AuthFlowIdentityUpdate(
      authoritativeIdentityChanged: authoritativeIdentityChanged,
      completion: .superseded(flowId: completion.flowId, ownerId: ownerId)
    )
  }
}

package final class AuthFlowRegistration: Sendable {
  package enum Role: Equatable {
    case root
    case dismissible
  }

  package enum PostAuthPresentation: Hashable {
    case sessionTasks
    case biometricCredentialEnrollment
  }

  package let id: UUID
  private let unregister: @MainActor @Sendable () -> Void

  init(
    id: UUID,
    unregister: @escaping @MainActor @Sendable () -> Void
  ) {
    self.id = id
    self.unregister = unregister
  }

  @MainActor
  package func cancel() {
    unregister()
  }

  deinit {
    let unregister = unregister
    Task { @MainActor in
      unregister()
    }
  }
}
