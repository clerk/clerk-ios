import ClerkKit
import Foundation
import Observation

/// Owns only native presentation; generated operations remain responsible for authentication.
@MainActor @Observable final class AuthFlowStore {
  private static let stores = NSMapTable<Clerk, AuthFlowStore>(keyOptions: [.weakMemory, .objectPointerPersonality], valueOptions: .strongMemory)
  private weak var clerk: Clerk?
  var coordinator = AuthFlowCoordinator()
  private var pendingCompletion: UUID?
  private var completions: [UUID: (ownerId: UUID?, task: Task<Void, Error>)] = [:]

  private init(clerk: Clerk) {
    self.clerk = clerk
  }

  static func owned(by clerk: Clerk) -> AuthFlowStore {
    if let store = stores.object(forKey: clerk) { return store }
    let store = AuthFlowStore(clerk: clerk)
    stores.setObject(store, forKey: clerk)
    return store
  }

  func unregister(ownerId: UUID) {
    for completion in completions.values where completion.ownerId == ownerId {
      completion.task.cancel()
    }
    if coordinator.ownerId == ownerId { pendingCompletion = nil }
    coordinator.unregister(ownerId: ownerId)
  }

  func reconcile() {
    guard pendingCompletion == nil, let clerk, let ownerId = coordinator.ownerId else { return }
    let current: AuthFlowCoordinator.Target? = switch coordinator.phase {
    case .observing: nil
    case .awaiting(let target), .presenting(let target, _): target
    }
    guard let session = clerk.session, session.isViableForPostAuth else {
      if current != nil || coordinator.completedSessionId != nil { coordinator.reset(ownerId: ownerId) }
      return
    }
    if let current, current.sessionId != session.id {
      coordinator.completedSessionId = nil
      coordinator.phase = .awaiting(coordinator.externalTarget(for: session))
      coordinator.advanceRevision()
    } else if current == nil, session.status == .pending || coordinator.completedSessionId != session.id {
      coordinator.completedSessionId = nil
      coordinator.phase = .awaiting(coordinator.externalTarget(for: session))
      coordinator.advanceRevision()
    }
  }

  func finalize(_ result: TransferFlowResult) async throws {
    guard result.isComplete, let clerk else { return }
    try Task.checkCancellation()
    let ownerId = AuthFlowRequestScope.ownerId
    if let ownerId, coordinator.ownerId != ownerId { throw CancellationError() }
    let completionId = UUID()
    var introducedWork = false
    if let ownerId, let sessionId = result.createdSessionId {
      pendingCompletion = completionId
      switch coordinator.phase {
      case .presenting(var target, let token) where target.sessionId == sessionId:
        // A repeated completion must not replace a screen the user is finishing.
        if target.completion == nil {
          target.origin = .completed(result)
          target.flowId = result.flowId
          coordinator.phase = .presenting(target: target, token: token)
        }
      case .awaiting(let target) where target.sessionId == sessionId && target.flowId == result.flowId:
        break
      default:
        introducedWork = true
        coordinator.completedSessionId = nil
        coordinator.phase = .awaiting(.init(id: completionId, sessionId: sessionId, origin: .completed(result), flowId: result.flowId))
      }
      coordinator.advanceRevision()
      guard coordinator.ownerId == ownerId else { throw CancellationError() }
    }
    let task = Task {
      try Task.checkCancellation()
      switch result {
      case .signIn(let signIn): try await signIn.finalize()
      case .signUp(let signUp): try await signUp.finalize()
      }
    }
    completions[completionId] = (ownerId, task)
    defer { completions[completionId] = nil }
    do {
      try await withTaskCancellationHandler {
        try await task.value
      } onCancel: {
        task.cancel()
      }
      try Task.checkCancellation()
      if let ownerId, coordinator.ownerId != ownerId { throw CancellationError() }
      guard let session = clerk.session, session.id == result.createdSessionId else { throw CancellationError() }
      if pendingCompletion == completionId {
        pendingCompletion = nil
        coordinator.advanceRevision()
      }
    } catch {
      if pendingCompletion == completionId {
        pendingCompletion = nil
        if let ownerId, coordinator.ownerId == ownerId {
          if introducedWork { coordinator.reset(ownerId: ownerId) }
          reconcile()
        }
      }
      throw error
    }
  }
}

extension Clerk {
  private var authFlowStore: AuthFlowStore {
    AuthFlowStore.owned(by: self)
  }

  public var isAuthFlowComplete: Bool {
    user != nil && session?.status == .active && !authFlowStore.coordinator.isRootBlocking
  }

  var authFlowRegistrationId: UUID? {
    authFlowStore.coordinator.ownerId
  }

  func authFlowSnapshot(for registration: AuthFlowRegistration) -> AuthFlowSnapshot? {
    authFlowStore.coordinator.snapshot(ownerId: registration.id)
  }

  func registerAuthFlow(role: AuthFlowRegistration.Role = .root) -> AuthFlowRegistration? {
    let store = authFlowStore
    guard let id = store.coordinator.register(role: role, hasActiveUserSession: user != nil && session?.status == .active) else { return nil }
    return AuthFlowRegistration(id: id) { store.unregister(ownerId: id) }
  }

  func resetAuthFlow(for registration: AuthFlowRegistration) {
    authFlowStore.coordinator.reset(ownerId: registration.id)
  }

  func adoptPendingAuthSession(for registration: AuthFlowRegistration, session: Session) {
    guard self.session?.id == session.id else { return }
    authFlowStore.coordinator.adoptPendingSession(ownerId: registration.id, session: session)
  }

  func authFlowPresentationIsCurrent(_ token: AuthFlowPresentationToken) -> Bool {
    session?.id == token.sessionId && authFlowStore.coordinator.presentationIsCurrent(token)
  }

  func startAuthFlowPresentation(for registration: AuthFlowRegistration, work: AuthFlowWork, presentation: AuthFlowRegistration.PostAuthPresentation) -> AuthFlowPresentationToken? {
    guard registration.id == work.ownerId, session?.id == work.sessionId else { return nil }
    return authFlowStore.coordinator.startPresentation(ownerId: registration.id, work: work, presentation: presentation)
  }

  @discardableResult func finishAuthFlowPresentation(_ token: AuthFlowPresentationToken) -> Bool {
    guard session?.id == token.sessionId else { return false }
    return authFlowStore.coordinator.finishPresentation(token: token)
  }

  func completeAuthFlow(_ work: AuthFlowWork) -> Bool {
    guard user != nil, session?.id == work.sessionId, session?.status == .active else { return false }
    return authFlowStore.coordinator.complete(work: work)
  }

  func reconcileAuthFlowPresentation() {
    authFlowStore.reconcile()
  }

  func authenticateWithSSOForPresentation(_ params: MobileSSOParams) async throws -> TransferFlowResult {
    let result = try await TransferFlowResult(authenticateWithSSO(params))
    try await finalizeForPresentation(result)
    return result
  }

  func finalizeForPresentation(_ result: TransferFlowResult) async throws {
    try await authFlowStore.finalize(result)
  }
}
