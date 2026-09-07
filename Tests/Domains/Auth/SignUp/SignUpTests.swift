@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct SignUpTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func sendEmailLinkSavesPendingFlowBeforePrepare() async throws {
    let keychain = InMemoryKeychain()
    let signUp = SignUp.mock
    let service = MockSignUpService(prepareVerification: { _, _ in
      throw ClerkClientError(message: "Prepare failed.")
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      signUpService: service
    )
    let magicLinkStore = Clerk.shared.dependencies.magicLinkStore

    await #expect(throws: ClerkClientError.self) {
      try await signUp.sendEmailLink()
    }
    let pendingFlow = try #require(magicLinkStore.load())
    #expect(pendingFlow.kind == .signUp)
    #expect(pendingFlow.flowId == signUp.id)
    #expect(pendingFlow.codeVerifier.isEmpty == false)
  }

  @Test
  func sendEmailLinkDoesNotPrepareWhenSavingPendingFlowFails() async throws {
    let prepareWasCalled = LockIsolated(false)
    let signUp = SignUp.mock
    let service = MockSignUpService(prepareVerification: { _, _ in
      prepareWasCalled.setValue(true)
      return .mock
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: SetFailingKeychain(),
      signUpService: service
    )

    await #expect(throws: SetFailingKeychain.Failure.self) {
      try await signUp.sendEmailLink()
    }
    #expect(prepareWasCalled.value == false)
  }
}
