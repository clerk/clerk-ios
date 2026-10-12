@testable import ClerkKit
#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
import AuthenticationServices
#endif
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct AuthTests {
  init() {
    configureClerkForTesting()
  }

  private func configureDependencies(
    transport: (any APITransport)? = nil,
    environment: Clerk.Environment? = .mock,
    keychain: (any KeychainStorage)? = nil,
    baseURL: URL = mockBaseUrl,
    options: Clerk.Options = .init()
  ) {
    configureClerkForTesting()
    let apiClient = createMockAPIClient(baseURL: baseURL)
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: apiClient,
      transport: transport ?? apiClient,
      keychain: keychain
    )
    try! (Clerk.shared.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: options)
    Clerk.shared.environment = environment
    Clerk.shared.setCallbackContinuation(nil)
  }

  private func makeIsolatedClerk(
    transport: (any APITransport)? = nil,
    environment: Clerk.Environment? = .mock,
    keychain: (any KeychainStorage)? = nil,
    baseURL: URL = mockBaseUrl,
    options: Clerk.Options = .init()
  ) -> Clerk {
    Clerk.shared.setCallbackContinuation(nil)
    let clerk = Clerk()
    let apiClient = createMockAPIClient(baseURL: baseURL, runtimeScope: clerk.runtimeScope)
    clerk.dependencies = MockDependencyContainer(
      apiClient: apiClient,
      transport: transport ?? apiClient,
      keychain: keychain
    )
    try! (clerk.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: options)
    clerk.environment = environment
    clerk.setCallbackContinuation(nil)
    return clerk
  }

  private func enabledBiometricCredentialEnvironment() -> Clerk.Environment {
    var environment = Clerk.Environment.mock
    environment.authConfig.nativeSettings = .init(
      apiEnabled: true,
      biometricSignInEnabled: true
    )
    return environment
  }

  struct SignOutScenario: Codable, Equatable {
    let sessionId: String?
  }

  struct SetActiveScenario: Codable, Equatable {
    let organizationId: String?
  }

  @Test
  func signInWithIdentifierCreatesSignIn() async throws {
    let signInParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { params in
      signInParams.setValue(params)
      return .mock
    }

    configureDependencies(transport: transport)

    _ = try await Clerk.shared.auth.signIn("test@example.com")

    let params = try #require(signInParams.value)
    #expect(params["identifier"]?.stringValue == "test@example.com")
  }

  @Test
  func signInWithPasswordCreatesSignIn() async throws {
    let signInParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { params in
      signInParams.setValue(params)
      return .mock
    }

    configureDependencies(transport: transport)

    _ = try await Clerk.shared.auth.signInWithPassword(identifier: "test@example.com", password: "password123")

    let params = try #require(signInParams.value)
    #expect(params["identifier"]?.stringValue == "test@example.com")
    #expect(params["password"]?.stringValue == "password123")
  }

  @Test
  func signInWithOAuthCreatesSignIn() async throws {
    let signUpCalled = LockIsolated(false)
    let signInParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { params in
      signInParams.setValue(params)
      return .mock
    }
    transport.stubSignUpCreate { _ in
      signUpCalled.setValue(true)
      return .mock
    }

    configureDependencies(transport: transport)

    let error = await #expect(throws: ClerkClientError.self) {
      try await Clerk.shared.auth.signInWithOAuth(provider: .google)
    }
    #expect(error?.messageLocalizationValue == "Redirect URL is missing or invalid. Unable to start external authentication flow.")

    #expect(signUpCalled.value == false)
    let params = try #require(signInParams.value)
    #expect(params["strategy"]?.stringValue == OAuthProvider.google.strategy)
  }

  @Test
  func signInWithEnterpriseSSOCreatesSignIn() async throws {
    let signUpCalled = LockIsolated(false)
    let signInParams = LockIsolated<JSON?>(nil)
    let prepareParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { params in
      signInParams.setValue(params)
      return .mock
    }
    transport.stubSignInPrepareFirstFactor { _, params in
      prepareParams.setValue(params)
      return .mock
    }
    transport.stubSignUpCreate { _ in
      signUpCalled.setValue(true)
      return .mock
    }

    configureDependencies(transport: transport)

    let error = await #expect(throws: ClerkClientError.self) {
      try await Clerk.shared.auth.signInWithEnterpriseSSO(
        emailAddress: "user@enterprise.com",
        enterpriseConnectionId: "ent_123"
      )
    }
    #expect(error?.messageLocalizationValue == "Redirect URL is missing or invalid. Unable to start external authentication flow.")

    #expect(signUpCalled.value == false)
    let params = try #require(signInParams.value)
    #expect(params["identifier"]?.stringValue == "user@enterprise.com")
    #expect(params["strategy"] == nil)

    let prepared = try #require(prepareParams.value)
    #expect(prepared["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .enterpriseSSO)
    #expect(prepared["enterprise_connection_id"]?.stringValue == "ent_123")
  }

  @Test
  func startEnterpriseSSOCreatesAndPreparesFirstFactor() async throws {
    let signInParams = LockIsolated<JSON?>(nil)
    let prepareParams = LockIsolated<(String, JSON?)?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { params in
      signInParams.setValue(params)
      return .mock
    }
    transport.stubSignInPrepareFirstFactor { id, params in
      prepareParams.setValue((id, params))
      return .mock
    }

    configureDependencies(transport: transport)

    _ = try await Clerk.shared.auth.startEnterpriseSSO(
      emailAddress: "user@enterprise.com",
      enterpriseConnectionId: "ent_123",
      redirectUrl: "myapp://callback"
    )

    let params = try #require(signInParams.value)
    #expect(params["identifier"]?.stringValue == "user@enterprise.com")
    #expect(params["strategy"] == nil)
    #expect(params["redirect_url"] == nil)

    let prepared = try #require(prepareParams.value)
    #expect(prepared.0 == SignIn.mock.id)
    #expect(prepared.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .enterpriseSSO)
    #expect(prepared.1?["redirect_url"]?.stringValue == "myapp://callback")
    #expect(prepared.1?["enterprise_connection_id"]?.stringValue == "ent_123")
  }

  @Test
  func startEnterpriseSSOOmitsTheConnectionIdWhenNoneIsGiven() async throws {
    let prepareParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { _ in .mock }
    transport.stubSignInPrepareFirstFactor { _, params in
      prepareParams.setValue(params)
      return .mock
    }

    configureDependencies(transport: transport)

    _ = try await Clerk.shared.auth.startEnterpriseSSO(emailAddress: "user@enterprise.com")

    let prepared = try #require(prepareParams.value)
    #expect(prepared["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .enterpriseSSO)
    #expect(prepared["enterprise_connection_id"] == nil)
  }

  @Test
  func signInWithIdTokenCreatesSignIn() async throws {
    let signUpCalled = LockIsolated(false)
    let signInParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { params in
      signInParams.setValue(params)
      return .mock
    }
    transport.stubSignUpCreate { _ in
      signUpCalled.setValue(true)
      return .mock
    }

    configureDependencies(transport: transport)

    _ = try await Clerk.shared.auth.signInWithIdToken("mock_id_token", provider: .apple)

    #expect(signUpCalled.value == false)
    let params = try #require(signInParams.value)
    #expect(params["strategy"]?.stringValue == IDTokenProvider.apple.strategy)
    #expect(params["token"]?.stringValue == "mock_id_token")
  }

  @Test
  func signInWithIdTokenTransfersUnsafeMetadataToSignUp() async throws {
    let metadata: JSON = ["plan": "pro"]
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(status: .transferable)

    let signUpParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { _ in
      signIn
    }
    transport.stubSignUpCreate { params in
      signUpParams.setValue(params)
      return .mock
    }

    configureDependencies(transport: transport)

    _ = try await Clerk.shared.auth.signInWithIdToken(
      "mock_id_token",
      provider: .apple,
      unsafeMetadata: metadata
    )

    let params = try #require(signUpParams.value)
    #expect(params["transfer"]?.boolValue == true)
    #expect(params["unsafe_metadata"] == metadata)
  }

  @Test
  func signInWithIdTokenThrowsWhenTransferableButDisallowed() async throws {
    let signUpCalled = LockIsolated(false)
    let didThrow = LockIsolated(false)
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(
      status: .transferable,
      strategy: .idToken(.apple),
      error: .mock
    )

    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { _ in
      signIn
    }
    transport.stubSignUpCreate { _ in
      signUpCalled.setValue(true)
      return .mock
    }

    configureDependencies(transport: transport)

    do {
      _ = try await Clerk.shared.auth.signInWithIdToken(
        "mock_id_token",
        provider: .apple,
        transferable: false
      )
      #expect(Bool(false))
    } catch {
      didThrow.setValue(true)
    }

    #expect(signUpCalled.value == false)
    #expect(didThrow.value == true)
  }

  @Test
  func createPasskeySignInUsesPasskeyStrategy() async throws {
    let signInParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { params in
      signInParams.setValue(params)
      return .mock
    }

    configureDependencies(transport: transport)

    let signIn = try await Clerk.shared.auth.createPasskeySignIn()

    #expect(signIn == .mock)
    let createParams = try #require(signInParams.value)
    #expect(createParams["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .passkey)
  }

  @Test
  func signInWithPasskeyUsesOneShotPasskeySignIn() async throws {
    var preparedSignIn = SignIn.mock
    preparedSignIn.firstFactorVerification = nil

    let signInParams = LockIsolated<JSON?>(nil)
    let preparedSignInId = LockIsolated<String?>(nil)
    let preparedParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { params in
      signInParams.setValue(params)
      return .mock
    }
    transport.stubSignInPrepareFirstFactor { signInId, params in
      preparedSignInId.setValue(signInId)
      preparedParams.setValue(params)
      return preparedSignIn
    }

    configureDependencies(transport: transport)

    let error = await #expect(throws: ClerkClientError.self) {
      try await Clerk.shared.auth.signInWithPasskey()
    }
    #expect(error?.messageLocalizationValue == "Unable to get the challenge for the passkey.")

    let createParams = try #require(signInParams.value)
    #expect(createParams["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .passkey)
    #expect(preparedSignInId.value == SignIn.mock.id)

    let prepareParams = try #require(preparedParams.value)
    #expect(prepareParams["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .passkey)
  }

  @Test
  func signInWithBiometricsDelegatesToBiometricCredentials() async throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut

    let createParams = LockIsolated<JSON?>(nil)
    let attemptedSignInId = LockIsolated<String?>(nil)
    let attemptParams = LockIsolated<JSON?>(nil)
    let signedLocalKeyIds = LockIsolated<[String]>([])
    let signedReasons = LockIsolated<[String?]>([])

    let challengeSignIn = SignIn(
      id: "si_trusted_device",
      status: .needsFirstFactor,
      firstFactorVerification: .init(
        status: .unverified,
        strategy: .biometricCredential,
        biometricCredentialChallenge: .mock
      )
    )
    let completedSignIn = SignIn(
      id: challengeSignIn.id,
      status: .complete,
      createdSessionId: "sess_trusted_device"
    )
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { params in
      createParams.setValue(params)
      return challengeSignIn
    }
    transport.stubSignInAttemptFirstFactor { signInId, params in
      attemptedSignInId.setValue(signInId)
      attemptParams.setValue(params)
      return completedSignIn
    }
    let keyManager = MockBiometricCredentialKeyManager(sign: { clientData, localKeyId, localizedReason in
      #expect(clientData == BiometricCredentialChallenge.mock.clientData)
      signedLocalKeyIds.withValue { $0.append(localKeyId) }
      signedReasons.withValue { $0.append(localizedReason) }
      return .init(clientData: clientData, signature: "biometric-credential-signature")
    })
    let credentialStore = BiometricCredentialLocalStore(keychain: InMemoryKeychain())
    try credentialStore.save(.init(
      id: BiometricCredentialLocalRecord.mock.id,
      localKeyId: BiometricCredentialLocalRecord.mock.localKeyId,
      userID: BiometricCredentialLocalRecord.mock.userID,
      appIdentifier: "com.clerk.example",
      createdAt: BiometricCredentialLocalRecord.mock.createdAt,
      updatedAt: BiometricCredentialLocalRecord.mock.updatedAt
    ))

    let auth = Auth(
      magicLinkStore: MagicLinkStore(keychain: InMemoryKeychain()),
      transport: transport,
      biometricCredentials: BiometricCredentials(
        transport: transport,
        keyManager: keyManager,
        credentialStore: credentialStore,
        appIdentifierProvider: { "com.clerk.example" }
      ),
      eventEmitter: EventEmitter<AuthEvent>(),
      urlHandlingCoordinator: URLHandlingCoordinator()
    )

    let signIn = try await auth.signInWithBiometrics(reason: "Use Face ID to sign in.")

    #expect(signIn == completedSignIn)
    #expect(createParams.value?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .biometricCredential)
    #expect(createParams.value?["trusted_device_id"]?.stringValue == BiometricCredentialLocalRecord.mock.id)
    #expect(attemptedSignInId.value == challengeSignIn.id)
    #expect(attemptParams.value?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .biometricCredential)
    #expect(attemptParams.value?["trusted_device_id"]?.stringValue == BiometricCredentialLocalRecord.mock.id)
    #expect(attemptParams.value?["client_data"]?.stringValue == BiometricCredentialChallenge.mock.clientData)
    #expect(attemptParams.value?["signature"]?.stringValue == "biometric-credential-signature")
    #expect(attemptParams.value?["algorithm"]?.stringValue == BiometricCredential.Algorithm.es256.rawValue)
    #expect(signedLocalKeyIds.value == [BiometricCredentialLocalRecord.mock.localKeyId])
    #expect(signedReasons.value == ["Use Face ID to sign in."])
  }

  @Test
  func signInWithTicketCreatesSignIn() async throws {
    let signInParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { params in
      signInParams.setValue(params)
      return .mock
    }

    configureDependencies(transport: transport)

    _ = try await Clerk.shared.auth.signInWithTicket("mock_ticket_value")

    let params = try #require(signInParams.value)
    #expect(params["ticket"]?.stringValue == "mock_ticket_value")
  }

  @Test
  func signInWithEmailLinkCreatesAndPreparesFirstFactor() async throws {
    let keychain = InMemoryKeychain()
    let createParams = LockIsolated<JSON?>(nil)
    let prepareParams = LockIsolated<JSON?>(nil)

    var signIn = SignIn.mock
    signIn.identifier = "test@example.com"
    signIn.supportedFirstFactors = [
      Factor(
        strategy: .emailLink,
        emailAddressId: "ema_123",
        safeIdentifier: "test@example.com"
      ),
    ]

    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { params in
      createParams.setValue(params)
      return signIn
    }
    transport.stubSignInPrepareFirstFactor { _, params in
      prepareParams.setValue(params)
      return signIn
    }

    configureDependencies(transport: transport, keychain: keychain)

    _ = try await Clerk.shared.auth.signInWithEmailLink(emailAddress: " test@example.com ")

    let capturedCreateParams = try #require(createParams.value)
    #expect(capturedCreateParams["identifier"]?.stringValue == "test@example.com")

    let capturedPrepareParams = try #require(prepareParams.value)
    #expect(capturedPrepareParams["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .emailLink)
    #expect(capturedPrepareParams["email_address_id"]?.stringValue == "ema_123")
    #expect(capturedPrepareParams["redirect_uri"]?.stringValue == Clerk.shared.options.redirectConfig.redirectUrl)
    #expect(capturedPrepareParams["code_challenge_method"]?.stringValue == PKCE.codeChallengeMethod)
    #expect(capturedPrepareParams["code_challenge"]?.stringValue?.isEmpty == false)

    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue))
    #expect(Clerk.shared.dependencies.magicLinkStore.load()?.flowId == signIn.id)
  }

  @Test
  func completeMagicLinkWithCallbackURLCompletesPendingFlowAndActivatesSession() async throws {
    let keychain = InMemoryKeychain()
    let signInParams = LockIsolated<JSON?>(nil)
    let activatedSessionId = LockIsolated<String?>(nil)
    let capturedAuthFlowOwnerId = LockIsolated<UUID?>(nil)
    let expectedAuthFlowOwnerId = UUID()

    let transport = FakeTransport.mockDefaults()
    transport.stub(MagicLinkAPI.complete(params: MagicLinkCompleteParams(flowId: "flow_123", approvalToken: "", codeVerifier: ""))) { call in
      capturedAuthFlowOwnerId.setValue(AuthFlowRequestScope.ownerId)
      return ClientResponse(
        response: .ticket(MagicLinkCompleteResponse(flowId: call.body?["flow_id"]?.stringValue, ticket: "ticket_123")),
        client: nil
      )
    }
    let completedSignIn = SignIn(
      id: "sign_in_123",
      status: .complete,
      createdSessionId: "sess_123"
    )
    transport.stubSignInCreate { params in
      signInParams.setValue(params)
      return completedSignIn
    }

    transport.stubSetActive { sessionId, _ in
      activatedSessionId.setValue(sessionId)
    }

    configureDependencies(
      transport: transport,
      keychain: keychain
    )
    let clerk = Clerk.shared
    let callbackURL = try #require(URL(string: "\(clerk.options.redirectConfig.redirectUrl)?flow_id=flow_123&approval_token=approval_123"))
    try clerk.dependencies.magicLinkStore.save(
      kind: .signIn,
      flowId: "flow_123",
      codeVerifier: "verifier_123",
      authFlowOwnerId: expectedAuthFlowOwnerId
    )
    let pendingFlow = try #require(clerk.dependencies.magicLinkStore.load())
    #expect(
      clerk.dependencies.magicLinkStore.authFlowOwnerId(for: pendingFlow)
        == expectedAuthFlowOwnerId
    )

    let result = try await clerk.auth.completeMagicLink(callbackURL: callbackURL)
    let signIn = switch result {
    case .signIn(let signIn):
      signIn
    case .signUp:
      Issue.record("Expected sign-in result for sign-in magic link completion.")
      throw ClerkClientError(message: "Expected sign-in result.")
    }

    let completeCall = try #require(transport.calls.first { $0.path == "/v1/client/magic_links/complete" })
    #expect(signIn.createdSessionId == "sess_123")
    #expect(completeCall.body?["flow_id"]?.stringValue == "flow_123")
    #expect(completeCall.body?["approval_token"]?.stringValue == "approval_123")
    #expect(completeCall.body?["code_verifier"]?.stringValue == "verifier_123")
    #expect(signInParams.value?["ticket"]?.stringValue == "ticket_123")
    #expect(activatedSessionId.value == "sess_123")
    #expect(capturedAuthFlowOwnerId.value == expectedAuthFlowOwnerId)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == false)
  }

  @Test
  func magicLinkAuthFlowOwnershipIsInMemoryOnly() throws {
    let keychain = InMemoryKeychain()
    let ownerId = UUID()
    let store = MagicLinkStore(keychain: keychain)
    try store.save(
      kind: .signIn,
      flowId: "flow_123",
      codeVerifier: "verifier_123",
      authFlowOwnerId: ownerId
    )

    let pendingFlow = try #require(store.load())
    #expect(store.authFlowOwnerId(for: pendingFlow) == ownerId)
    let sameFlowWithDifferentDates = PendingMagicLinkFlow(
      kind: pendingFlow.kind,
      flowId: pendingFlow.flowId,
      codeVerifier: pendingFlow.codeVerifier,
      createdAt: pendingFlow.createdAt.addingTimeInterval(1),
      expiresAt: pendingFlow.expiresAt.addingTimeInterval(1)
    )
    #expect(store.authFlowOwnerId(for: sameFlowWithDifferentDates) == ownerId)

    let relaunchedStore = MagicLinkStore(keychain: keychain)
    let reloadedFlow = try #require(relaunchedStore.load())
    #expect(relaunchedStore.authFlowOwnerId(for: reloadedFlow) == nil)
  }

  @Test
  func completeMagicLinkWithCallbackURLRejectsMissingCallbackParams() async throws {
    let transport = FakeTransport.mockDefaults()

    configureDependencies(transport: transport)
    let callbackURL = try #require(URL(string: "\(Clerk.shared.options.redirectConfig.redirectUrl)?flow_id=flow_123"))

    await #expect(throws: ClerkClientError.self) {
      try await Clerk.shared.auth.completeMagicLink(callbackURL: callbackURL)
    }

    #expect(transport.calls.contains { $0.path == "/v1/client/magic_links/complete" } == false)
  }

  @Test
  func completeMagicLinkEmitsContinuationEventForIncompleteSignIn() async throws {
    let keychain = InMemoryKeychain()
    let signInParams = LockIsolated<[String: String]?>(nil)
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-continuation.clerk.accounts.dev"))
    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!
    let syncedClient = Client(
      id: "client_123",
      signIn: nil,
      signUp: nil,
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )

    let completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse(
            response: MagicLinkCompleteResponse(flowId: "flow_123", ticket: "ticket_123"),
            client: syncedClient
          )
        ),
      ],
      additionalHeaders: ["Authorization": "completed-sign-up-token"]
    )
    completionMock.register()

    let resumableSignIn = SignIn(
      id: "sign_in_123",
      status: .needsSecondFactor,
      createdSessionId: nil
    )

    try registerSignInCreateMock(baseURL: testBaseUrl, response: resumableSignIn, signInParams: signInParams)
    try registerSetActiveMock(baseURL: testBaseUrl, sessionId: "sess_123", activatedSessionId: activatedSessionId)

    let clerk = makeIsolatedClerk(
      keychain: keychain,
      baseURL: testBaseUrl
    )
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, flowId: "flow_123", codeVerifier: "verifier_123")

    let capturedEvent = try await captureNextAuthEvent(from: clerk) {
      let result = try await clerk.auth.completeMagicLink(flowId: "flow_123", approvalToken: "approval_123")
      let signIn = switch result {
      case .signIn(let signIn):
        signIn
      case .signUp:
        Issue.record("Expected sign-in result for sign-in magic link completion.")
        throw ClerkClientError(message: "Expected sign-in result.")
      }
      #expect(signIn.status == .needsSecondFactor)
      #expect(signIn.createdSessionId == nil)
    }

    let event = try #require(capturedEvent)
    switch event {
    case .signInNeedsContinuation(let signIn):
      #expect(signIn.id == "sign_in_123")
      #expect(signIn.status == .needsSecondFactor)
    default:
      Issue.record("Expected signInNeedsContinuation event but received \(String(describing: event))")
    }

    #expect(signInParams.value?["ticket"] == "ticket_123")
    #expect(activatedSessionId.value == nil)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == false)
  }

  @Test
  func completeMagicLinkRejectsTicketResponseForSignUpFlow() async throws {
    let keychain = InMemoryKeychain()
    let signInParams = LockIsolated<[String: String]?>(nil)
    let signUpParams = LockIsolated<[String: String]?>(nil)
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-signup.clerk.accounts.dev"))
    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!

    let completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse(
            response: MagicLinkCompleteResponse(flowId: "flow_123", ticket: "ticket_123"),
            client: .mock
          )
        ),
      ]
    )
    completionMock.register()

    try registerSignInCreateMock(baseURL: testBaseUrl, signInParams: signInParams)
    try registerSignUpCreateMock(baseURL: testBaseUrl, signUpParams: signUpParams)
    try registerSetActiveMock(baseURL: testBaseUrl, sessionId: "sess_123", activatedSessionId: activatedSessionId)

    let clerk = makeIsolatedClerk(
      keychain: keychain,
      baseURL: testBaseUrl
    )
    try clerk.dependencies.magicLinkStore.save(kind: .signUp, flowId: "flow_123", codeVerifier: "verifier_123")

    await #expect(throws: ClerkClientError.self) {
      try await clerk.auth.completeMagicLink(flowId: "flow_123", approvalToken: "approval_123")
    }

    #expect(signInParams.value == nil)
    #expect(signUpParams.value == nil)
    #expect(activatedSessionId.value == nil)
    #expect(Clerk.shared.callbackContinuation == nil)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == false)
  }

  @Test
  func completeMagicLinkUsesCompletedSignUpResponse() async throws {
    let keychain = InMemoryKeychain()
    let signUpParams = LockIsolated<[String: String]?>(nil)
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-signup-response.clerk.accounts.dev"))
    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!

    var pendingSignUp = SignUp.mock
    pendingSignUp.id = "sign_up_123"
    pendingSignUp.status = .missingRequirements
    pendingSignUp.unverifiedFields = [.emailAddress]

    var completedSignUp = pendingSignUp
    completedSignUp.status = .complete
    completedSignUp.missingFields = []
    completedSignUp.unverifiedFields = []
    completedSignUp.createdSessionId = "sess_123"
    completedSignUp.createdUserId = "user_123"

    var pendingSession = Session.mock
    pendingSession.id = "sess_123"
    pendingSession.status = .pending

    let syncedClient = Client(
      id: "client_123",
      signIn: nil,
      signUp: nil,
      sessions: [pendingSession],
      lastActiveSessionId: pendingSession.id,
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_891)
    )

    let completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse(
            response: completedSignUp,
            client: syncedClient
          )
        ),
      ],
      additionalHeaders: ["Authorization": "completed-sign-up-token"]
    )
    completionMock.register()

    try registerSignUpCreateMock(baseURL: testBaseUrl, signUpParams: signUpParams)
    try registerSetActiveMock(baseURL: testBaseUrl, sessionId: "sess_123", activatedSessionId: activatedSessionId)

    let clerk = makeIsolatedClerk(
      keychain: keychain,
      baseURL: testBaseUrl
    )
    clerk.client = Client(
      id: "client_123",
      signIn: nil,
      signUp: pendingSignUp,
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
    try clerk.dependencies.magicLinkStore.save(kind: .signUp, flowId: "flow_123", codeVerifier: "verifier_123")

    var result: TransferFlowResult?
    let capturedEvent = try await captureNextAuthEvent(from: clerk) {
      result = try await clerk.auth.completeMagicLink(flowId: "flow_123", approvalToken: "approval_123")
    }

    let signUp = switch try #require(result) {
    case .signUp(let signUp):
      signUp
    case .signIn:
      Issue.record("Expected sign-up result for sign-up magic link callback.")
      throw ClerkClientError(message: "Expected sign-up result.")
    }

    #expect(signUpParams.value == nil)
    #expect(activatedSessionId.value == nil)
    #expect(signUp.id == "sign_up_123")
    #expect(signUp.status == .complete)
    #expect(signUp.createdSessionId == "sess_123")
    #expect(clerk.client?.currentSession?.id == "sess_123")
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == false)

    let event = try #require(capturedEvent)
    switch event {
    case .sessionChanged(let oldValue, let newValue):
      #expect(oldValue == nil)
      #expect(newValue?.id == "sess_123")
    default:
      Issue.record("Expected sessionChanged event but received \(String(describing: event))")
    }
  }

  @Test
  func completeMagicLinkEmitsContinuationEventForIncompleteSignUp() async throws {
    let keychain = InMemoryKeychain()
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-signup-continuation.clerk.accounts.dev"))
    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!

    var resumableSignUp = SignUp.mock
    resumableSignUp.status = .missingRequirements
    resumableSignUp.createdSessionId = nil
    let syncedClient = Client(
      id: "client_123",
      signIn: nil,
      signUp: resumableSignUp,
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )

    let completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse(
            response: resumableSignUp,
            client: syncedClient
          )
        ),
      ]
    )
    completionMock.register()

    try registerSetActiveMock(baseURL: testBaseUrl, sessionId: "sess_123", activatedSessionId: activatedSessionId)

    let clerk = makeIsolatedClerk(
      keychain: keychain,
      baseURL: testBaseUrl
    )
    try clerk.dependencies.magicLinkStore.save(kind: .signUp, flowId: "flow_123", codeVerifier: "verifier_123")

    let capturedEvent = try await captureNextAuthEvent(from: clerk) {
      let result = try await clerk.auth.completeMagicLink(flowId: "flow_123", approvalToken: "approval_123")
      let signUp = switch result {
      case .signUp(let signUp):
        signUp
      case .signIn:
        Issue.record("Expected sign-up result for sign-up magic link callback.")
        throw ClerkClientError(message: "Expected sign-up result.")
      }
      #expect(signUp.status == .missingRequirements)
      #expect(signUp.createdSessionId == nil)
    }

    let event = try #require(capturedEvent)
    switch event {
    case .signUpNeedsContinuation(let signUp):
      #expect(signUp.id == resumableSignUp.id)
      #expect(signUp.status == .missingRequirements)
    default:
      Issue.record("Expected signUpNeedsContinuation event but received \(String(describing: event))")
    }

    #expect(activatedSessionId.value == nil)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == false)
  }

  @Test
  func urlHandlingCoordinatorDeduplicatesConcurrentRoutes() async throws {
    let coordinator = URLHandlingCoordinator()
    let invocationCount = LockIsolated(0)
    let route = ClerkURLRoute.magicLink(flowId: "flow_123", approvalToken: "approval_123")
    let expectedResult = TransferFlowResult.signIn(SignIn(
      id: "sign_in_123",
      status: .complete,
      createdSessionId: "sess_123"
    ))

    async let first = coordinator.handle(route) {
      invocationCount.withValue { $0 += 1 }
      try await Task.sleep(for: .milliseconds(50))
      return expectedResult
    }
    async let second = coordinator.handle(route) {
      invocationCount.withValue { $0 += 1 }
      return expectedResult
    }

    let (firstResult, secondResult) = try await (first, second)
    let firstSignIn = switch firstResult {
    case .signIn(let signIn):
      signIn
    case .signUp:
      Issue.record("Expected sign-in result for first deduped route.")
      throw ClerkClientError(message: "Expected sign-in result.")
    }
    let secondSignIn = switch secondResult {
    case .signIn(let signIn):
      signIn
    case .signUp:
      Issue.record("Expected sign-in result for second deduped route.")
      throw ClerkClientError(message: "Expected sign-in result.")
    }

    #expect(firstSignIn.createdSessionId == "sess_123")
    #expect(secondSignIn.createdSessionId == "sess_123")
    #expect(invocationCount.value == 1)
  }

  @Test
  func completeMagicLinkRejectsMismatchedPendingFlowAndPreservesVerifier() async throws {
    let keychain = InMemoryKeychain()
    let signInParams = LockIsolated<[String: String]?>(nil)
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-stale.clerk.accounts.dev"))

    try registerSignInCreateMock(baseURL: testBaseUrl, signInParams: signInParams)
    try registerSetActiveMock(baseURL: testBaseUrl, sessionId: "sess_123", activatedSessionId: activatedSessionId)

    let clerk = makeIsolatedClerk(
      keychain: keychain,
      baseURL: testBaseUrl
    )
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, flowId: "flow_new", codeVerifier: "verifier_new")

    await #expect(throws: ClerkClientError.self) {
      try await clerk.auth.completeMagicLink(flowId: "flow_old", approvalToken: "approval_old")
    }

    #expect(signInParams.value == nil)
    #expect(activatedSessionId.value == nil)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == true)
    #expect(clerk.dependencies.magicLinkStore.load()?.flowId == "flow_new")
    #expect(clerk.dependencies.magicLinkStore.load()?.codeVerifier == "verifier_new")
  }

  @Test
  func completeMagicLinkCompletesPendingFlowAndActivatesSession() async throws {
    let keychain = InMemoryKeychain()
    let signInParams = LockIsolated<[String: String]?>(nil)
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-complete-dedupe.clerk.accounts.dev"))

    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!

    let completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse(
            response: MagicLinkCompleteResponse(flowId: "flow_123", ticket: "ticket_123"),
            client: .mock
          )
        ),
      ]
    )
    completionMock.register()

    let completedSignIn = SignIn(
      id: "sign_in_123",
      status: .complete,
      createdSessionId: "sess_123"
    )

    try registerSignInCreateMock(baseURL: testBaseUrl, response: completedSignIn, signInParams: signInParams)
    try registerSetActiveMock(baseURL: testBaseUrl, sessionId: "sess_123", activatedSessionId: activatedSessionId)

    let clerk = makeIsolatedClerk(
      keychain: keychain,
      baseURL: testBaseUrl
    )
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, flowId: "flow_123", codeVerifier: "verifier_123")

    let result = try await clerk.auth.completeMagicLink(flowId: "flow_123", approvalToken: "approval_123")
    let signIn = switch result {
    case .signIn(let signIn):
      signIn
    case .signUp:
      Issue.record("Expected sign-in result for sign-in magic link completion.")
      throw ClerkClientError(message: "Expected sign-in result.")
    }

    #expect(signIn.createdSessionId == "sess_123")
    #expect(signInParams.value?["ticket"] == "ticket_123")
    #expect(activatedSessionId.value == "sess_123")
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == false)
  }

  @Test
  func completeMagicLinkClearsPendingFlowOnTerminalCompletionFailure() async throws {
    let keychain = InMemoryKeychain()
    let signInParams = LockIsolated<[String: String]?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-complete-terminal.clerk.accounts.dev"))
    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!

    let completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 422,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClerkErrorResponse(
            errors: [
              ClerkAPIError(
                code: "approval_token_expired",
                message: "The approval token has expired.",
                longMessage: nil,
                meta: nil,
                clerkTraceId: nil
              ),
            ],
            clerkTraceId: nil
          )
        ),
      ]
    )
    completionMock.register()

    try registerSignInCreateMock(baseURL: testBaseUrl, signInParams: signInParams)

    let clerk = makeIsolatedClerk(
      keychain: keychain,
      baseURL: testBaseUrl
    )
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, flowId: "flow_123", codeVerifier: "verifier_123")

    await #expect(throws: ClerkAPIError.self) {
      try await clerk.auth.completeMagicLink(flowId: "flow_123", approvalToken: "approval_123")
    }

    #expect(signInParams.value == nil)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == false)
  }

  @Test
  func completeMagicLinkPreservesPendingFlowOnRetryableCompletionFailure() async throws {
    let keychain = InMemoryKeychain()
    let signInParams = LockIsolated<[String: String]?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-complete-retryable.clerk.accounts.dev"))
    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!

    let completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 500,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClerkErrorResponse(
            errors: [
              ClerkAPIError(
                code: "server_error",
                message: "Try again.",
                longMessage: nil,
                meta: nil,
                clerkTraceId: nil
              ),
            ],
            clerkTraceId: nil
          )
        ),
      ]
    )
    completionMock.register()

    try registerSignInCreateMock(baseURL: testBaseUrl, signInParams: signInParams)

    let clerk = makeIsolatedClerk(
      keychain: keychain,
      baseURL: testBaseUrl
    )
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, flowId: "flow_123", codeVerifier: "verifier_123")

    await #expect(throws: ClerkAPIError.self) {
      try await clerk.auth.completeMagicLink(flowId: "flow_123", approvalToken: "approval_123")
    }

    let pendingFlow = try #require(clerk.dependencies.magicLinkStore.load())
    #expect(signInParams.value == nil)
    #expect(pendingFlow.flowId == "flow_123")
    #expect(pendingFlow.codeVerifier == "verifier_123")
  }

  @Test
  func completeMagicLinkDoesNotClearNewerPendingFlow() async throws {
    let keychain = InMemoryKeychain()
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-complete-newer.clerk.accounts.dev"))
    let magicLinkStore = MagicLinkStore(keychain: keychain)

    let completedSignIn = SignIn(
      id: "sign_in_123",
      status: .complete,
      createdSessionId: "sess_123"
    )

    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { _ in
      completedSignIn
    }
    transport.stub(MagicLinkAPI.complete(params: MagicLinkCompleteParams(flowId: "flow_123", approvalToken: "", codeVerifier: ""))) { _ in
      try magicLinkStore.save(kind: .signIn, flowId: "flow_new", codeVerifier: "verifier_new")
      return ClientResponse(response: .ticket(MagicLinkCompleteResponse(flowId: "flow_123", ticket: "ticket_123")), client: nil)
    }

    transport.stubSetActive { sessionId, _ in
      activatedSessionId.setValue(sessionId)
    }

    let clerk = makeIsolatedClerk(
      transport: transport,
      keychain: keychain,
      baseURL: testBaseUrl
    )
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, flowId: "flow_123", codeVerifier: "verifier_123")

    _ = try await clerk.auth.completeMagicLink(flowId: "flow_123", approvalToken: "approval_123")

    let pendingFlow = try #require(clerk.dependencies.magicLinkStore.load())
    #expect(pendingFlow.flowId == "flow_new")
    #expect(pendingFlow.codeVerifier == "verifier_new")
    #expect(activatedSessionId.value == "sess_123")
  }

  private func captureNextAuthEvent(
    from clerk: Clerk,
    timeout: Duration = .milliseconds(250),
    operation: () async throws -> Void
  ) async throws -> AuthEvent? {
    let captured = LockIsolated<AuthEvent?>(nil)
    var listener: Task<Void, Never>?
    await withCheckedContinuation { (ready: CheckedContinuation<Void, Never>) in
      listener = Task { @MainActor in
        var iterator = clerk.auth.events.makeAsyncIterator()
        ready.resume()
        if let event = await iterator.next() {
          captured.setValue(event)
        }
      }
    }
    defer { listener?.cancel() }

    try await operation()

    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if let event = captured.value {
        return event
      }

      try await Task.sleep(for: .milliseconds(10))
    }

    return captured.value
  }

  @Test
  func signUpWithStandardFieldsCreatesSignUp() async throws {
    let signUpParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignUpCreate { params in
      signUpParams.setValue(params)
      return .mock
    }

    configureDependencies(transport: transport)

    _ = try await Clerk.shared.auth.signUp(emailAddress: "test@example.com", password: "password123")

    let params = try #require(signUpParams.value)
    #expect(params["email_address"]?.stringValue == "test@example.com")
    #expect(params["password"]?.stringValue == "password123")
    #expect(params["transfer"] == nil)
  }

  @Test
  func signUpTransfersCurrentSignInWithCollectedFields() async throws {
    let metadata: JSON = ["birthday": "1990-01-01"]
    let signUpParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignUpCreate { params in
      signUpParams.setValue(params)
      return .mock
    }

    configureDependencies(transport: transport)

    let signUp = try await Clerk.shared.auth.signUp(
      unsafeMetadata: metadata,
      legalAccepted: true,
      transfer: true
    )

    #expect(signUp == .mock)
    let params = try #require(signUpParams.value)
    #expect(params["unsafe_metadata"] == metadata)
    #expect(params["legal_accepted"]?.boolValue == true)
    #expect(params["transfer"]?.boolValue == true)
  }

  @Test
  func signUpWithOAuthCreatesSignUp() async throws {
    let metadata: JSON = ["plan": "pro"]
    let signInCalled = LockIsolated(false)
    let signUpParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { _ in
      signInCalled.setValue(true)
      return .mock
    }
    transport.stubSignUpCreate { params in
      signUpParams.setValue(params)
      return .mock
    }

    configureDependencies(transport: transport)

    let error = await #expect(throws: ClerkClientError.self) {
      try await Clerk.shared.auth.signUpWithOAuth(
        provider: .google,
        unsafeMetadata: metadata
      )
    }
    #expect(error?.messageLocalizationValue == "Redirect URL is missing or invalid. Unable to start external authentication flow.")

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params["strategy"]?.stringValue == OAuthProvider.google.strategy)
    #expect(params["unsafe_metadata"] == metadata)
  }

  @Test
  func signUpWithEnterpriseSSOCreatesSignUp() async throws {
    let metadata: JSON = ["plan": "pro"]
    let signInCalled = LockIsolated(false)
    let signUpParams = LockIsolated<JSON?>(nil)
    let updateParams = LockIsolated<(String, JSON?)?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { _ in
      signInCalled.setValue(true)
      return .mock
    }
    transport.stubSignUpCreate { params in
      signUpParams.setValue(params)
      return .mock
    }
    transport.stubSignUpUpdate { id, params in
      updateParams.setValue((id, params))
      return .mock
    }

    configureDependencies(transport: transport)

    let error = await #expect(throws: ClerkClientError.self) {
      try await Clerk.shared.auth.signUpWithEnterpriseSSO(
        emailAddress: "user@enterprise.com",
        enterpriseConnectionId: "ent_123",
        unsafeMetadata: metadata
      )
    }
    #expect(error?.messageLocalizationValue == "Redirect URL is missing or invalid. Unable to start external authentication flow.")

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params["email_address"]?.stringValue == "user@enterprise.com")
    #expect(params["unsafe_metadata"] == metadata)
    #expect(params["strategy"] == nil)

    let updated = try #require(updateParams.value)
    #expect(updated.0 == SignUp.mock.id)
    #expect(updated.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .enterpriseSSO)
    #expect(updated.1?["redirect_url"]?.stringValue == Clerk.shared.options.redirectConfig.redirectUrl)
    #expect(updated.1?["enterprise_connection_id"]?.stringValue == "ent_123")
  }

  @Test
  func signUpWithIdTokenCreatesSignUp() async throws {
    let metadata: JSON = ["plan": "pro"]
    let signInCalled = LockIsolated(false)
    let signUpParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignInCreate { _ in
      signInCalled.setValue(true)
      return .mock
    }
    transport.stubSignUpCreate { params in
      signUpParams.setValue(params)
      return .mock
    }

    configureDependencies(transport: transport)

    _ = try await Clerk.shared.auth.signUpWithIdToken(
      "mock_id_token",
      provider: .apple,
      unsafeMetadata: metadata
    )

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params["strategy"]?.stringValue == IDTokenProvider.apple.strategy)
    #expect(params["token"]?.stringValue == "mock_id_token")
    #expect(params["unsafe_metadata"] == metadata)
  }

  @Test
  func signUpWithIdTokenPreservesEnabledNameFields() async throws {
    let signUpParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignUpCreate { params in
      signUpParams.setValue(params)
      return .mock
    }

    configureDependencies(transport: transport)

    _ = try await Clerk.shared.auth.signUpWithIdToken(
      "mock_id_token",
      provider: .apple,
      firstName: "Jane",
      lastName: "Doe"
    )

    let params = try #require(signUpParams.value)
    #expect(params["first_name"]?.stringValue == "Jane")
    #expect(params["last_name"]?.stringValue == "Doe")
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @Test
  func normalizedAppleScopesDropsFullNameWhenBothNameFieldsAreDisabled() {
    var environment = Clerk.Environment.mock
    environment.userSettings.attributes["first_name"]?.enabled = false
    environment.userSettings.attributes["last_name"]?.enabled = false

    let scopes = Auth.normalizedAppleScopes(
      [.email, .fullName],
      environment: environment
    )

    #expect(scopes == [.email])
  }

  @Test
  func normalizedAppleScopesKeepsFullNameWhenEitherNameFieldIsEnabled() {
    var environment = Clerk.Environment.mock
    environment.userSettings.attributes["first_name"]?.enabled = true
    environment.userSettings.attributes["last_name"]?.enabled = false

    let scopes = Auth.normalizedAppleScopes(
      [.email, .fullName],
      environment: environment
    )

    #expect(scopes == [.email, .fullName])
  }

  @Test
  func normalizedAppleScopesKeepsFullNameWhenEnvironmentIsUnavailable() {
    let scopes = Auth.normalizedAppleScopes(
      [.email, .fullName],
      environment: nil
    )

    #expect(scopes == [.email, .fullName])
  }
  #endif

  @Test
  func signUpWithTicketCreatesSignUp() async throws {
    let metadata: JSON = ["plan": "pro"]
    let signUpParams = LockIsolated<JSON?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSignUpCreate { params in
      signUpParams.setValue(params)
      return .mock
    }

    configureDependencies(transport: transport)

    _ = try await Clerk.shared.auth.signUpWithTicket(
      "mock_ticket_value",
      unsafeMetadata: metadata
    )

    let params = try #require(signUpParams.value)
    #expect(params["ticket"]?.stringValue == "mock_ticket_value")
    #expect(params["unsafe_metadata"] == metadata)
  }

  @Test(
    arguments: [
      SignOutScenario(sessionId: nil),
      SignOutScenario(sessionId: "sess_test123"),
    ]
  )
  func signOutRemovesRequestedSessions(
    scenario: SignOutScenario
  ) async throws {
    let transport = FakeTransport.mockDefaults()

    configureDependencies(transport: transport)

    try await Clerk.shared.auth.signOut(sessionId: scenario.sessionId)

    let call = try #require(transport.calls.last)
    if let sessionId = scenario.sessionId {
      #expect(call.method == .post)
      #expect(call.path == "/v1/client/sessions/\(sessionId)/remove")
    } else {
      #expect(call.method == .delete)
      #expect(call.path == "/v1/client/sessions")
    }
  }

  @Test(
    arguments: [
      SetActiveScenario(organizationId: nil),
      SetActiveScenario(organizationId: "org_test456"),
    ]
  )
  func setActiveTouchesSessionWithOrganization(
    scenario: SetActiveScenario
  ) async throws {
    let activeParams = LockIsolated<(String, String?)?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSetActive { sessionId, body in
      activeParams.setValue((sessionId, body?["active_organization_id"]?.stringValue))
    }

    configureDependencies(transport: transport)

    try await Clerk.shared.auth.setActive(
      sessionId: "sess_test123",
      organizationId: scenario.organizationId
    )

    let params = try #require(activeParams.value)
    #expect(params.0 == "sess_test123")
    #expect(params.1 == (scenario.organizationId ?? ""))
  }

  @Test
  func setActiveClearsOrganizationByDefault() async throws {
    let activeParams = LockIsolated<(String, String?)?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubSetActive { sessionId, body in
      activeParams.setValue((sessionId, body?["active_organization_id"]?.stringValue))
    }

    configureDependencies(transport: transport)

    try await Clerk.shared.auth.setActive(sessionId: "sess_test123")

    let params = try #require(activeParams.value)
    #expect(params.0 == "sess_test123")
    #expect(params.1 == "")
  }

  @Test
  func recoveredSessionActivationWaitsForAuthViewCompletion() async throws {
    struct ActivationError: Error {}

    let transport = FakeTransport.mockDefaults()
    transport.stubSetActive { _, _ in
      throw ActivationError()
    }
    configureDependencies(transport: transport)
    Clerk.shared.client = nil
    let registration = try #require(Clerk.shared.registerAuthFlow())
    let sessionId = try #require(Client.mock.currentSession?.id)
    let activation = try #require(Clerk.shared.beginAuthSessionActivation(
      sessionId: sessionId,
      ownerId: registration.id
    ))
    Clerk.shared.client = .mock

    try await Clerk.shared.auth.activateSession(
      sessionId: sessionId,
      authFlowActivation: activation
    )

    let snapshot = try #require(Clerk.shared.authFlowSnapshot(for: registration))
    guard case .awaiting(let work, _) = snapshot.phase else {
      Issue.record("Expected the recovered session to await AuthView completion")
      return
    }
    #expect(Clerk.shared.isAuthFlowComplete == false)
    #expect(Clerk.shared.completeAuthFlow(work))
    #expect(Clerk.shared.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }
}

@MainActor
private func registerSetActiveMock(baseURL: URL, sessionId: String, activatedSessionId: LockIsolated<String?>) throws {
  var mock = try Mock(
    url: #require(URL(string: baseURL.absoluteString + "/v1/client/sessions/\(sessionId)/touch")),
    ignoreQuery: true,
    contentType: .json,
    statusCode: 200,
    data: [
      .post: JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: .mock, client: nil)),
    ]
  )
  mock.onRequestHandler = OnRequestHandler { @Sendable _ in
    activatedSessionId.setValue(sessionId)
  }
  mock.register()
}

@MainActor
private func registerSignUpCreateMock(baseURL: URL, signUpParams: LockIsolated<[String: String]?>) throws {
  var mock = try Mock(
    url: #require(URL(string: baseURL.absoluteString + "/v1/client/sign_ups")),
    ignoreQuery: true,
    contentType: .json,
    statusCode: 200,
    data: [
      .post: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: nil)),
    ]
  )
  mock.onRequestHandler = OnRequestHandler { @Sendable request in
    signUpParams.setValue(request.urlEncodedFormBody)
  }
  mock.register()
}

@MainActor
private func registerSignInCreateMock(
  baseURL: URL,
  response: SignIn = .mock,
  signInParams: LockIsolated<[String: String]?>
) throws {
  var mock = try Mock(
    url: #require(URL(string: baseURL.absoluteString + "/v1/client/sign_ins")),
    ignoreQuery: true,
    contentType: .json,
    statusCode: 200,
    data: [
      .post: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: response, client: nil)),
    ]
  )
  mock.onRequestHandler = OnRequestHandler { @Sendable request in
    signInParams.setValue(request.urlEncodedFormBody)
  }
  mock.register()
}
