@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct SignUpTests {
  private let transport = FakeTransport.mockDefaults()

  init() {
    configureClerkForTesting()
  }

  private func useTransport(keychain: (any KeychainStorage)? = nil) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport,
      keychain: keychain
    )
  }

  struct ReloadScenario: Codable, Equatable {
    let rotatingTokenNonce: String?
  }

  @Test
  func updatePatchesSignUpFields() async throws {
    let signUp = SignUp.mock

    useTransport()

    _ = try await signUp.update(firstName: "John", lastName: "Doe", legalAccepted: true)

    let call = try #require(transport.calls.last)
    #expect(call.method == .patch)
    #expect(call.path == "/v1/client/sign_ups/\(signUp.id)")
    #expect(call.body?["first_name"]?.stringValue == "John")
    #expect(call.body?["last_name"]?.stringValue == "Doe")
    #expect(call.body?["legal_accepted"]?.boolValue == true)
  }

  @Test
  func sendEmailLinkPreparesEmailLinkVerification() async throws {
    let keychain = InMemoryKeychain()
    let signUp = SignUp.mock

    useTransport(keychain: keychain)
    let magicLinkStore = Clerk.shared.dependencies.magicLinkStore

    _ = try await signUp.sendEmailLink()

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/client/sign_ups/\(signUp.id)/prepare_verification")
    #expect(call.body?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .emailLink)
    #expect(call.body?["email_address_id"] == nil)
    #expect(call.body?["redirect_uri"]?.stringValue == Clerk.shared.options.redirectConfig.redirectUrl)
    #expect(call.body?["code_challenge_method"]?.stringValue == PKCE.codeChallengeMethod)
    #expect(call.body?["code_challenge"]?.stringValue?.isEmpty == false)

    let pendingFlow = try #require(magicLinkStore.load())
    #expect(pendingFlow.kind == .signUp)
    #expect(pendingFlow.flowId == signUp.id)
    #expect(pendingFlow.codeVerifier.isEmpty == false)
  }

  @Test
  func sendEmailLinkSavesPendingFlowBeforePrepare() async throws {
    let keychain = InMemoryKeychain()
    let signUp = SignUp.mock
    transport.stub(SignUpAPI.prepareVerification(signUpId: FakeTransport.anyPathSegment, params: .init(strategy: .emailLink))) { _ in
      throw ClerkClientError(message: "Prepare failed.")
    }

    useTransport(keychain: keychain)
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

    useTransport(keychain: SetFailingKeychain())

    await #expect(throws: SetFailingKeychain.Failure.self) {
      try await signUp.sendEmailLink()
    }
    #expect(!transport.calls.contains { $0.path.hasSuffix("/prepare_verification") })
  }

  @Test
  func sendEmailCodePreparesEmailCodeVerification() async throws {
    let signUp = SignUp.mock

    useTransport()

    _ = try await signUp.sendEmailCode()

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/client/sign_ups/\(signUp.id)/prepare_verification")
    #expect(call.body?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .emailCode)
  }

  @Test
  func sendPhoneCodePreparesPhoneCodeVerification() async throws {
    let signUp = SignUp.mock

    useTransport()

    _ = try await signUp.sendPhoneCode()

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/client/sign_ups/\(signUp.id)/prepare_verification")
    #expect(call.body?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .phoneCode)
  }

  @Test
  func verifyEmailCodeAttemptsEmailCodeVerification() async throws {
    let signUp = SignUp.mock

    useTransport()

    _ = try await signUp.verifyEmailCode("123456")

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/client/sign_ups/\(signUp.id)/attempt_verification")
    #expect(call.body?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .emailCode)
    #expect(call.body?["code"]?.stringValue == "123456")
  }

  @Test
  func verifyPhoneCodeAttemptsPhoneCodeVerification() async throws {
    let signUp = SignUp.mock

    useTransport()

    _ = try await signUp.verifyPhoneCode("654321")

    let call = try #require(transport.calls.last)
    #expect(call.path == "/v1/client/sign_ups/\(signUp.id)/attempt_verification")
    #expect(call.body?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .phoneCode)
    #expect(call.body?["code"]?.stringValue == "654321")
  }

  @Test(
    arguments: [
      ReloadScenario(rotatingTokenNonce: nil),
      ReloadScenario(rotatingTokenNonce: "test_nonce"),
    ]
  )
  func reloadFetchesSignUpWithNonce(
    scenario: ReloadScenario
  ) async throws {
    let signUp = SignUp.mock

    useTransport()

    _ = try await signUp.reload(rotatingTokenNonce: scenario.rotatingTokenNonce)

    let call = try #require(transport.calls.last)
    #expect(call.method == .get)
    #expect(call.path == "/v1/client/sign_ups/\(signUp.id)")
    #expect(call.query.first { $0.name == "rotating_token_nonce" }?.value == scenario.rotatingTokenNonce)
  }
}
