import Foundation

final class AuthFlowRegistration: Sendable {
  enum Role: Equatable {
    case root
    case dismissible
  }

  enum PostAuthPresentation: Hashable {
    case sessionTasks
    case biometricCredentialEnrollment
  }

  let id: UUID
  private let unregister: @MainActor @Sendable () -> Void

  init(
    id: UUID,
    unregister: @escaping @MainActor @Sendable () -> Void
  ) {
    self.id = id
    self.unregister = unregister
  }

  @MainActor
  func cancel() {
    unregister()
  }

  deinit {
    let unregister = unregister
    Task { @MainActor in
      unregister()
    }
  }
}
