@testable import ClerkKit
import ClerkSnapshots
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct SignInTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func handleTransferFlowSkipsSignUpWhenNotTransferable() async throws {
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(status: .transferable)

    let engine = RecordingEngineClient()
    engine.nativeCompletionResult = .signIn(signIn)
    Clerk.engineClient = engine
    let result = try await signIn.handleTransferFlow(transferable: false)

    switch result {
    case .signIn:
      break
    case .signUp:
      #expect(Bool(false))
    }
  }
}
