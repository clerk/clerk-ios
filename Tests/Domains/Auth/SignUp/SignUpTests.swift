@testable import ClerkKit
import ClerkSnapshots
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
    let engine = ThrowingJSEngine(message: "Prepare failed.")
    Clerk.engineClient = engine

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain
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
    let signUp = SignUp.mock
    let engine = CountingJSEngine()
    Clerk.engineClient = engine

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: SetFailingKeychain()
    )

    await #expect(throws: SetFailingKeychain.Failure.self) {
      try await signUp.sendEmailLink()
    }
    #expect(engine.invokeCount == 0)
  }
}

@MainActor
private final class ThrowingJSEngine: ClerkEngineClient {
  let message: String

  init(message: String) {
    self.message = message
  }

  func invoke(_: ClerkJSInvocation) async throws -> JSONValue {
    throw ClerkClientError(message: String.LocalizationValue(stringLiteral: message))
  }
}

@MainActor
private final class CountingJSEngine: ClerkEngineClient {
  var invokeCount = 0

  func invoke(_: ClerkJSInvocation) async throws -> JSONValue {
    invokeCount += 1
    return .null
  }
}
