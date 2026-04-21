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
    signInService: MockSignInService? = nil,
    signUpService: MockSignUpService? = nil,
    sessionService: MockSessionService? = nil,
    environment: Clerk.Environment? = .mock,
    keychain: (any KeychainStorage)? = nil,
    baseURL: URL = mockBaseUrl,
    options: Clerk.Options = .init()
  ) {
    configureClerkForTesting()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(baseURL: baseURL),
      keychain: keychain,
      signInService: signInService,
      signUpService: signUpService,
      sessionService: sessionService
    )
    try! (Clerk.shared.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: options)
    Clerk.shared.environment = environment
    Clerk.shared.setCallbackContinuation(nil)
  }

  private func makeIsolatedClerk(
    signInService: MockSignInService? = nil,
    signUpService: MockSignUpService? = nil,
    sessionService: MockSessionService? = nil,
    environment: Clerk.Environment? = .mock,
    keychain: (any KeychainStorage)? = nil,
    baseURL: URL = mockBaseUrl,
    options: Clerk.Options = .init()
  ) -> Clerk {
    Clerk.shared.setCallbackContinuation(nil)
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(baseURL: baseURL),
      keychain: keychain,
      signInService: signInService,
      signUpService: signUpService,
      sessionService: sessionService
    )
    try! (clerk.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: options)
    clerk.environment = environment
    clerk.setCallbackContinuation(nil)
    return clerk
  }

  struct SignOutScenario: Codable, Equatable {
    let sessionId: String?
  }

  struct SetActiveScenario: Codable, Equatable {
    let organizationId: String?
  }

  @Test
  func signInWithIdentifierUsesSignInServiceCreate() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService)

    _ = try await Clerk.shared.auth.signIn("test@example.com")

    let params = try #require(signInParams.value)
    #expect(params.identifier == "test@example.com")
  }

  @Test
  func signInWithPasswordUsesSignInServiceCreate() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService)

    _ = try await Clerk.shared.auth.signInWithPassword(identifier: "test@example.com", password: "password123")

    let params = try #require(signInParams.value)
    #expect(params.identifier == "test@example.com")
    #expect(params.password == "password123")
  }

  @Test
  func signInWithOAuthUsesSignInServiceCreate() async throws {
    let signUpCalled = LockIsolated(false)
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })
    let signUpService = MockSignUpService(create: { _ in
      signUpCalled.setValue(true)
      return .mock
    })

    configureDependencies(signInService: signInService, signUpService: signUpService)

    do {
      _ = try await Clerk.shared.auth.signInWithOAuth(provider: .google)
    } catch {
      // Expected to fail in unit tests due to missing external verification data.
    }

    #expect(signUpCalled.value == false)
    let params = try #require(signInParams.value)
    #expect(params.strategy?.rawValue == OAuthProvider.google.strategy)
  }

  @Test
  func signInWithEnterpriseSSOUsesSignInServiceCreate() async throws {
    let signUpCalled = LockIsolated(false)
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })
    let signUpService = MockSignUpService(create: { _ in
      signUpCalled.setValue(true)
      return .mock
    })

    configureDependencies(signInService: signInService, signUpService: signUpService)

    do {
      _ = try await Clerk.shared.auth.signInWithEnterpriseSSO(emailAddress: "user@enterprise.com")
    } catch {
      // Expected to fail in unit tests due to missing external verification data.
    }

    #expect(signUpCalled.value == false)
    let params = try #require(signInParams.value)
    #expect(params.identifier == "user@enterprise.com")
  }

  @Test
  func signInWithIdTokenUsesSignInServiceCreate() async throws {
    let signUpCalled = LockIsolated(false)
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })
    let signUpService = MockSignUpService(create: { _ in
      signUpCalled.setValue(true)
      return .mock
    })

    configureDependencies(signInService: signInService, signUpService: signUpService)

    _ = try await Clerk.shared.auth.signInWithIdToken("mock_id_token", provider: .apple)

    #expect(signUpCalled.value == false)
    let params = try #require(signInParams.value)
    #expect(params.strategy?.rawValue == IDTokenProvider.apple.strategy)
    #expect(params.token == "mock_id_token")
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

    let signInService = MockSignInService(create: { _ in
      signIn
    })
    let signUpService = MockSignUpService(create: { _ in
      signUpCalled.setValue(true)
      return .mock
    })

    configureDependencies(signInService: signInService, signUpService: signUpService)

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
  func signInWithPasskeyUsesOneShotPasskeySignIn() async throws {
    var preparedSignIn = SignIn.mock
    preparedSignIn.firstFactorVerification = nil

    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let preparedSignInId = LockIsolated<String?>(nil)
    let preparedParams = LockIsolated<SignIn.PrepareFirstFactorParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    }, prepareFirstFactor: { signInId, params in
      preparedSignInId.setValue(signInId)
      preparedParams.setValue(params)
      return preparedSignIn
    })

    configureDependencies(signInService: signInService)

    do {
      _ = try await Clerk.shared.auth.signInWithPasskey()
    } catch {
      // Expected to fail in unit tests because no passkey challenge/credential is available.
    }

    let createParams = try #require(signInParams.value)
    #expect(createParams.strategy == .passkey)
    #expect(preparedSignInId.value == SignIn.mock.id)

    let prepareParams = try #require(preparedParams.value)
    #expect(prepareParams.strategy == .passkey)
  }

  @Test
  func signInWithTicketUsesSignInServiceCreate() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService)

    _ = try await Clerk.shared.auth.signInWithTicket("mock_ticket_value")

    let params = try #require(signInParams.value)
    #expect(params.ticket == "mock_ticket_value")
  }

  @Test
  func signInWithEmailLinkCreatesAndPreparesFirstFactor() async throws {
    let keychain = InMemoryKeychain()
    let createParams = LockIsolated<SignIn.CreateParams?>(nil)
    let prepareParams = LockIsolated<SignIn.PrepareFirstFactorParams?>(nil)

    var signIn = SignIn.mock
    signIn.identifier = "test@example.com"
    signIn.supportedFirstFactors = [
      Factor(
        strategy: .emailLink,
        emailAddressId: "ema_123",
        safeIdentifier: "test@example.com"
      ),
    ]

    let signInService = MockSignInService(
      create: { params in
        createParams.setValue(params)
        return signIn
      },
      prepareFirstFactor: { _, params in
        prepareParams.setValue(params)
        return signIn
      }
    )

    configureDependencies(signInService: signInService, keychain: keychain)

    _ = try await Clerk.shared.auth.signInWithEmailLink(emailAddress: " test@example.com ")

    let capturedCreateParams = try #require(createParams.value)
    #expect(capturedCreateParams.identifier == "test@example.com")

    let capturedPrepareParams = try #require(prepareParams.value)
    #expect(capturedPrepareParams.strategy == .emailLink)
    #expect(capturedPrepareParams.emailAddressId == "ema_123")
    #expect(capturedPrepareParams.redirectUri == Clerk.shared.options.redirectConfig.redirectUrl)
    #expect(capturedPrepareParams.codeChallengeMethod == MagicLinkPKCE.codeChallengeMethod)
    #expect(capturedPrepareParams.codeChallenge?.isEmpty == false)

    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue))
  }

  @Test
  func handleMagicLinkCallbackCompletesPendingFlowAndActivatesSession() async throws {
    let keychain = InMemoryKeychain()
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-success.clerk.accounts.dev"))
    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!

    var completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          MagicLinkCompleteResponse(flowId: "flow_123", ticket: "ticket_123")
        ),
      ]
    )

    completionMock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody?["flow_id"] == "flow_123")
      #expect(request.urlEncodedFormBody?["approval_token"] == "approval_123")
      #expect(request.urlEncodedFormBody?["code_verifier"] == "verifier_123")
    }
    completionMock.register()

    let completedSignIn = SignIn(
      id: "sign_in_123",
      status: .complete,
      createdSessionId: "sess_123"
    )

    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return completedSignIn
    })
    let sessionService = MockSessionService(setActive: { sessionId, _ in
      activatedSessionId.setValue(sessionId)
    })

    let clerk = makeIsolatedClerk(
      signInService: signInService,
      sessionService: sessionService,
      keychain: keychain,
      baseURL: testBaseUrl
    )
    let callbackUrl = try #require(URL(string: "\(clerk.options.redirectConfig.redirectUrl)?flow_id=flow_123&approval_token=approval_123"))
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, codeVerifier: "verifier_123")

    let result = try await clerk.auth.handleMagicLinkCallback(callbackUrl)
    let signIn = switch result {
    case .signIn(let signIn):
      signIn
    case .signUp:
      Issue.record("Expected sign-in result for sign-in magic link callback.")
      throw ClerkClientError(message: "Expected sign-in result.")
    }

    #expect(signIn.createdSessionId == "sess_123")
    #expect(signInParams.value?.ticket == "ticket_123")
    #expect(activatedSessionId.value == "sess_123")
    #expect(Clerk.shared.callbackContinuation == nil)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == false)
  }

  @Test
  func handleMagicLinkCallbackEmitsContinuationEventForIncompleteSignIn() async throws {
    let keychain = InMemoryKeychain()
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-continuation.clerk.accounts.dev"))
    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!

    let completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          MagicLinkCompleteResponse(flowId: "flow_123", ticket: "ticket_123")
        ),
      ]
    )
    completionMock.register()

    let resumableSignIn = SignIn(
      id: "sign_in_123",
      status: .needsSecondFactor,
      createdSessionId: nil
    )

    let signInService = MockSignInService(create: { params in
      #expect(params.ticket == "ticket_123")
      return resumableSignIn
    })
    let sessionService = MockSessionService(setActive: { sessionId, _ in
      activatedSessionId.setValue(sessionId)
    })

    let clerk = makeIsolatedClerk(
      signInService: signInService,
      sessionService: sessionService,
      keychain: keychain,
      baseURL: testBaseUrl
    )
    let callbackUrl = try #require(URL(string: "\(clerk.options.redirectConfig.redirectUrl)?flow_id=flow_123&approval_token=approval_123"))
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, codeVerifier: "verifier_123")

    let capturedEvent = try await captureNextAuthEvent(from: clerk) {
      let result = try await clerk.auth.handleMagicLinkCallback(callbackUrl)
      let signIn = switch result {
      case .signIn(let signIn):
        signIn
      case .signUp:
        Issue.record("Expected sign-in result for sign-in magic link callback.")
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

    #expect(activatedSessionId.value == nil)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == false)
  }

  @Test
  func handleMagicLinkCallbackUsesSignUpTicketPath() async throws {
    let keychain = InMemoryKeychain()
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
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
          MagicLinkCompleteResponse(flowId: "flow_123", ticket: "ticket_123")
        ),
      ]
    )
    completionMock.register()

    var completedSignUp = SignUp.mock
    completedSignUp.status = .complete
    completedSignUp.createdSessionId = "sess_123"

    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return completedSignUp
    })
    let sessionService = MockSessionService(setActive: { sessionId, _ in
      activatedSessionId.setValue(sessionId)
    })

    let clerk = makeIsolatedClerk(
      signInService: signInService,
      signUpService: signUpService,
      sessionService: sessionService,
      keychain: keychain,
      baseURL: testBaseUrl
    )
    let callbackUrl = try #require(URL(string: "\(clerk.options.redirectConfig.redirectUrl)?flow_id=flow_123&approval_token=approval_123"))
    try clerk.dependencies.magicLinkStore.save(kind: .signUp, codeVerifier: "verifier_123")

    let result = try await clerk.auth.handleMagicLinkCallback(callbackUrl)
    let signUp = switch result {
    case .signUp(let signUp):
      signUp
    case .signIn:
      Issue.record("Expected sign-up result for sign-up magic link callback.")
      throw ClerkClientError(message: "Expected sign-up result.")
    }

    #expect(signInParams.value == nil)
    #expect(signUpParams.value?.ticket == "ticket_123")
    #expect(signUp.createdSessionId == "sess_123")
    #expect(activatedSessionId.value == "sess_123")
    #expect(Clerk.shared.callbackContinuation == nil)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == false)
  }

  @Test
  func handleMagicLinkCallbackEmitsContinuationEventForIncompleteSignUp() async throws {
    let keychain = InMemoryKeychain()
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-signup-continuation.clerk.accounts.dev"))
    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!

    let completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          MagicLinkCompleteResponse(flowId: "flow_123", ticket: "ticket_123")
        ),
      ]
    )
    completionMock.register()

    var resumableSignUp = SignUp.mock
    resumableSignUp.status = .missingRequirements
    resumableSignUp.createdSessionId = nil

    let signUpService = MockSignUpService(create: { params in
      #expect(params.ticket == "ticket_123")
      return resumableSignUp
    })
    let sessionService = MockSessionService(setActive: { sessionId, _ in
      activatedSessionId.setValue(sessionId)
    })

    let clerk = makeIsolatedClerk(
      signUpService: signUpService,
      sessionService: sessionService,
      keychain: keychain,
      baseURL: testBaseUrl
    )
    let callbackUrl = try #require(URL(string: "\(clerk.options.redirectConfig.redirectUrl)?flow_id=flow_123&approval_token=approval_123"))
    try clerk.dependencies.magicLinkStore.save(kind: .signUp, codeVerifier: "verifier_123")

    let capturedEvent = try await captureNextAuthEvent(from: clerk) {
      let result = try await clerk.auth.handleMagicLinkCallback(callbackUrl)
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
  func handleMagicLinkCallbackDeduplicatesConcurrentCallbacks() async throws {
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
  func handleMagicLinkCallbackPreservesPendingFlowAfterStalePkceFailure() async throws {
    let keychain = InMemoryKeychain()
    let signInCalled = LockIsolated(false)
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-stale.clerk.accounts.dev"))
    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!

    var completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 400,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClerkErrorResponse(
            errors: [
              ClerkAPIError(
                code: "pkce_verification_failed",
                message: "PKCE verification failed.",
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
    completionMock.onRequestHandler = OnRequestHandler { request in
      #expect(request.urlEncodedFormBody?["flow_id"] == "flow_old")
      #expect(request.urlEncodedFormBody?["approval_token"] == "approval_old")
      #expect(request.urlEncodedFormBody?["code_verifier"] == "verifier_new")
    }
    completionMock.register()

    let signInService = MockSignInService(create: { _ in
      signInCalled.setValue(true)
      return .mock
    })
    let sessionService = MockSessionService(setActive: { sessionId, _ in
      activatedSessionId.setValue(sessionId)
    })

    let clerk = makeIsolatedClerk(
      signInService: signInService,
      sessionService: sessionService,
      keychain: keychain,
      baseURL: testBaseUrl
    )
    let callbackUrl = try #require(URL(string: "\(clerk.options.redirectConfig.redirectUrl)?flow_id=flow_old&approval_token=approval_old"))
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, codeVerifier: "verifier_new")

    do {
      _ = try await clerk.auth.handleMagicLinkCallback(callbackUrl)
      #expect(Bool(false), "Expected stale callback to fail")
    } catch let error as ClerkAPIError {
      #expect(error.code == "pkce_verification_failed")
    }

    #expect(signInCalled.value == false)
    #expect(activatedSessionId.value == nil)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == true)
    #expect(clerk.dependencies.magicLinkStore.load()?.codeVerifier == "verifier_new")
  }

  @Test
  func canHandleMagicLinkCallbackRejectsMismatchedOrigin() throws {
    configureDependencies()
    let clerk = Clerk.shared

    let mismatchedUrl = try #require(URL(string: "https://example.com/callback?flow_id=flow_123&approval_token=approval_123"))

    #expect(clerk.auth.canHandleMagicLinkCallback(mismatchedUrl) == false)
  }

  @Test
  func handleMagicLinkCallbackRejectsMismatchedOrigin() async throws {
    configureDependencies()
    let clerk = Clerk.shared

    let mismatchedUrl = try #require(URL(string: "https://example.com/callback?flow_id=flow_123&approval_token=approval_123"))

    await #expect(throws: ClerkClientError.self) {
      try await clerk.auth.handleMagicLinkCallback(mismatchedUrl)
    }
  }

  @Test
  func completeMagicLinkCompletesPendingFlowAndActivatesSession() async throws {
    let keychain = InMemoryKeychain()
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-authtests-complete-dedupe.clerk.accounts.dev"))

    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!

    var completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          MagicLinkCompleteResponse(flowId: "flow_123", ticket: "ticket_123")
        ),
      ]
    )
    completionMock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody?["flow_id"] == "flow_123")
      #expect(request.urlEncodedFormBody?["approval_token"] == "approval_123")
      #expect(request.urlEncodedFormBody?["code_verifier"] == "verifier_123")
    }
    completionMock.register()

    let completedSignIn = SignIn(
      id: "sign_in_123",
      status: .complete,
      createdSessionId: "sess_123"
    )

    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return completedSignIn
    })
    let sessionService = MockSessionService(setActive: { sessionId, _ in
      activatedSessionId.setValue(sessionId)
    })

    let clerk = makeIsolatedClerk(
      signInService: signInService,
      sessionService: sessionService,
      keychain: keychain,
      baseURL: testBaseUrl
    )
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, codeVerifier: "verifier_123")

    let result = try await clerk.auth.completeMagicLink(flowId: "flow_123", approvalToken: "approval_123")
    let signIn = switch result {
    case .signIn(let signIn):
      signIn
    case .signUp:
      Issue.record("Expected sign-in result for sign-in magic link completion.")
      throw ClerkClientError(message: "Expected sign-in result.")
    }

    #expect(signIn.createdSessionId == "sess_123")
    #expect(signInParams.value?.ticket == "ticket_123")
    #expect(activatedSessionId.value == "sess_123")
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == false)
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
  func signUpWithStandardFieldsUsesSignUpServiceCreate() async throws {
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return .mock
    })

    configureDependencies(signUpService: signUpService)

    _ = try await Clerk.shared.auth.signUp(emailAddress: "test@example.com", password: "password123")

    let params = try #require(signUpParams.value)
    #expect(params.emailAddress == "test@example.com")
    #expect(params.password == "password123")
  }

  @Test
  func signUpWithOAuthUsesSignUpServiceCreate() async throws {
    let signInCalled = LockIsolated(false)
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
    let signInService = MockSignInService(create: { _ in
      signInCalled.setValue(true)
      return .mock
    })
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService, signUpService: signUpService)

    do {
      _ = try await Clerk.shared.auth.signUpWithOAuth(provider: .google)
    } catch {
      // Expected to fail in unit tests due to missing external verification data.
    }

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params.strategy?.rawValue == OAuthProvider.google.strategy)
  }

  @Test
  func signUpWithEnterpriseSSOUsesSignUpServiceCreate() async throws {
    let signInCalled = LockIsolated(false)
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
    let signInService = MockSignInService(create: { _ in
      signInCalled.setValue(true)
      return .mock
    })
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService, signUpService: signUpService)

    do {
      _ = try await Clerk.shared.auth.signUpWithEnterpriseSSO(emailAddress: "user@enterprise.com")
    } catch {
      // Expected to fail in unit tests due to missing external verification data.
    }

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params.emailAddress == "user@enterprise.com")
  }

  @Test
  func signUpWithIdTokenUsesSignUpServiceCreate() async throws {
    let signInCalled = LockIsolated(false)
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
    let signInService = MockSignInService(create: { _ in
      signInCalled.setValue(true)
      return .mock
    })
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService, signUpService: signUpService)

    _ = try await Clerk.shared.auth.signUpWithIdToken("mock_id_token", provider: .apple)

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params.strategy?.rawValue == IDTokenProvider.apple.strategy)
    #expect(params.token == "mock_id_token")
  }

  @Test
  func signUpWithIdTokenPreservesEnabledNameFields() async throws {
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return .mock
    })

    configureDependencies(signUpService: signUpService)

    _ = try await Clerk.shared.auth.signUpWithIdToken(
      "mock_id_token",
      provider: .apple,
      firstName: "Jane",
      lastName: "Doe"
    )

    let params = try #require(signUpParams.value)
    #expect(params.firstName == "Jane")
    #expect(params.lastName == "Doe")
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
  func signUpWithTicketUsesSignUpServiceCreate() async throws {
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return .mock
    })

    configureDependencies(signUpService: signUpService)

    _ = try await Clerk.shared.auth.signUpWithTicket("mock_ticket_value")

    let params = try #require(signUpParams.value)
    #expect(params.ticket == "mock_ticket_value")
  }

  @Test(
    arguments: [
      SignOutScenario(sessionId: nil),
      SignOutScenario(sessionId: "sess_test123"),
    ]
  )
  func signOutUsesSessionServiceSignOut(
    scenario: SignOutScenario
  ) async throws {
    let signOutSessionId = LockIsolated<String?>(nil)
    let sessionService = MockSessionService(signOut: { sessionId in
      signOutSessionId.setValue(sessionId)
    })

    configureDependencies(sessionService: sessionService)

    try await Clerk.shared.auth.signOut(sessionId: scenario.sessionId)

    #expect(signOutSessionId.value == scenario.sessionId)
  }

  @Test(
    arguments: [
      SetActiveScenario(organizationId: nil),
      SetActiveScenario(organizationId: "org_test456"),
    ]
  )
  func setActiveUsesSessionServiceSetActive(
    scenario: SetActiveScenario
  ) async throws {
    let activeParams = LockIsolated<(String, String?)?>(nil)
    let sessionService = MockSessionService(setActive: { sessionId, organizationId in
      activeParams.setValue((sessionId, organizationId))
    })

    configureDependencies(sessionService: sessionService)

    try await Clerk.shared.auth.setActive(
      sessionId: "sess_test123",
      organizationId: scenario.organizationId
    )

    let params = try #require(activeParams.value)
    #expect(params.0 == "sess_test123")
    #expect(params.1 == scenario.organizationId)
  }
}
