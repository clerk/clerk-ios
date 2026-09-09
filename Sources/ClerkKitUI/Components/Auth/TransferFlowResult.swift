import ClerkKit

/// The generated attempt currently presented by the authentication UI.
enum TransferFlowResult {
  case signIn(SignIn)
  case signUp(SignUp)

  @MainActor init(_ result: MobileAuthenticationResult) {
    switch result {
    case .case1(let value): self = .signIn(value.signIn)
    case .case2(let value): self = .signUp(value.signUp)
    }
  }

  @MainActor var flowId: String {
    switch self {
    case .signIn(let value): value.id ?? value.handle.id
    case .signUp(let value): value.id ?? value.handle.id
    }
  }

  @MainActor var createdSessionId: String? {
    switch self { case .signIn(let value): value.createdSessionId; case .signUp(let value): value.createdSessionId }
  }

  @MainActor var isComplete: Bool {
    switch self { case .signIn(let value): value.status == .complete; case .signUp(let value): value.status == .complete }
  }

  @MainActor var needsContinuation: Bool {
    !isComplete
  }
}
