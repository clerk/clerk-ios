@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

struct HostedAuthProtocolTests {
  @Test
  func modeUsesHostedAuthProtocolValues() {
    #expect(HostedAuthMode.signIn.rawValue == "sign-in")
    #expect(HostedAuthMode.signUp.rawValue == "sign-up")
  }

  @Test
  func hostedAuthResourceRequiresExpectedObjectAndWebOrigin() throws {
    let resource = HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
    #expect(try resource.authenticationUrl().absoluteString == resource.url)

    for invalidResource in [
      HostedAuthResource(object: "client", url: resource.url),
      HostedAuthResource(object: "hosted_auth", url: "https:missing-host"),
      HostedAuthResource(object: "hosted_auth", url: "http://accounts.example.com/sign-in"),
      HostedAuthResource(object: "hosted_auth", url: "https://user@accounts.example.com/sign-in"),
      HostedAuthResource(object: "hosted_auth", url: "myapp://callback"),
    ] {
      #expect(throws: ClerkClientError.self) {
        try invalidResource.authenticationUrl()
      }
    }
  }

  @Test
  func pkceChallengeMatchesRFC7636Vector() {
    let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

    #expect(PKCE.challenge(for: verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
  }

  @Test
  func generatedPKCEPairUsesS256CompatibleValues() throws {
    let pair = try PKCE.generatePair()

    #expect(pair.verifier.count == 43)
    #expect(pair.challenge.count == 43)
    #expect(pair.verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    #expect(pair.challenge == PKCE.challenge(for: pair.verifier))
  }

  @Test
  func generatedStateIsRandomAndNonEmpty() throws {
    let first = try HostedAuthState.generate()
    let second = try HostedAuthState.generate()

    #expect(!first.isEmpty)
    #expect(first != second)
  }

  @Test
  func redirectMatchesSchemeAuthorityPortAndPath() throws {
    let redirect = try HostedAuthRedirect("myapp://expected.example:4242/callback")
    let valid = try #require(URL(string: "myapp://expected.example:4242/callback?state=state_123"))
    #expect(redirect.matches(valid))

    for rawValue in [
      "other://expected.example:4242/callback",
      "myapp://other.example:4242/callback",
      "myapp://expected.example:4243/callback",
      "myapp://expected.example:4242/other",
      "myapp://user@expected.example:4242/callback",
    ] {
      let callback = try #require(URL(string: rawValue))
      #expect(!redirect.matches(callback), "Expected callback to be rejected: \(rawValue)")
    }
  }

  @Test
  func tripleSlashRedirectRejectsInjectedOrMissingAuthority() throws {
    let redirect = try HostedAuthRedirect("myapp:///hosted-auth-callback")
    let valid = try #require(URL(string: "myapp:///hosted-auth-callback?state=state_123"))
    let injectedHost = try #require(URL(string: "myapp://attacker/hosted-auth-callback?state=state_123"))
    let missingAuthority = try #require(URL(string: "myapp:/hosted-auth-callback?state=state_123"))

    #expect(redirect.matches(valid))
    #expect(!redirect.matches(injectedHost))
    #expect(!redirect.matches(missingAuthority))
  }

  @Test
  func callbackRequiresExactStateNonceAndCreatedSession() throws {
    let redirect = try HostedAuthRedirect("myapp:///hosted-auth-callback")
    let callbackUrl = try makeHostedAuthCallbackUrl(
      redirectUrl: redirect.rawValue,
      state: "state_123",
      rotatingTokenNonce: "nonce_123",
      createdSessionId: "sess_123"
    )

    let callback = try HostedAuthCallback(url: callbackUrl, redirect: redirect, state: "state_123")
    #expect(callback.rotatingTokenNonce == "nonce_123")
    #expect(callback.createdSessionId == "sess_123")

    #expect(throws: ClerkClientError.self) {
      try HostedAuthCallback(url: callbackUrl, redirect: redirect, state: "other_state")
    }

    let missingNonce = try #require(URL(string: "myapp:///hosted-auth-callback?state=state_123&created_session_id=sess_123"))
    #expect(throws: ClerkClientError.self) {
      try HostedAuthCallback(url: missingNonce, redirect: redirect, state: "state_123")
    }

    let missingCreatedSession = try #require(URL(string: "myapp:///hosted-auth-callback?state=state_123&rotating_token_nonce=nonce_123"))
    #expect(throws: ClerkClientError.self) {
      try HostedAuthCallback(url: missingCreatedSession, redirect: redirect, state: "state_123")
    }

    let duplicateState = try #require(URL(string: "myapp:///hosted-auth-callback?state=state_123&state=state_123&rotating_token_nonce=nonce_123&created_session_id=sess_123"))
    #expect(throws: ClerkClientError.self) {
      try HostedAuthCallback(url: duplicateState, redirect: redirect, state: "state_123")
    }
  }
}

@MainActor
@Suite(.serialized)
struct HostedAuthFlowTests {
  @Test
  func successRedeemsUpdatesClientAndActivatesOnlyCallbackSession() async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    let redeemParams = LockIsolated<HostedAuthRedeemParams?>(nil)
    let browserInputs = LockIsolated<HostedAuthBrowserInputs?>(nil)
    let setActiveCall = LockIsolated<HostedAuthSetActiveCall?>(nil)

    var redeemedClient = Client.mock
    redeemedClient.sessions = [.mock, .mock2]
    redeemedClient.lastActiveSessionId = Session.mock.id
    var activatedClient = redeemedClient
    activatedClient.lastActiveSessionId = Session.mock2.id

    let hostedAuthService = MockHostedAuthService(
      create: { params in
        createParams.setValue(params)
        return HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
      },
      redeem: { params in
        redeemParams.setValue(params)
        guard let createParams = createParams.value else {
          throw ClerkClientError(message: "Missing create params in test.")
        }
        #expect(PKCE.challenge(for: params.codeVerifier) == createParams.codeChallenge)
        return ClientServiceResponse(client: redeemedClient, requestSequence: nil, serverDate: nil)
      }
    )
    let sessionService = MockSessionService(setActive: { sessionId, organizationId in
      setActiveCall.setValue(HostedAuthSetActiveCall(sessionId: sessionId, organizationId: organizationId))
      Clerk.shared.client = activatedClient
    })
    configureHostedAuthForTesting(
      hostedAuthService: hostedAuthService,
      sessionService: sessionService,
      initialClient: .mockSignedOut
    )

    let session = try await Clerk.shared.auth.performHostedAuth(
      mode: .signUp,
      redirectUrl: "myapp:///hosted-auth-callback",
      prefersEphemeralWebBrowserSession: false,
      webAuthentication: { url, callbackUrlScheme, prefersEphemeral in
        browserInputs.setValue(HostedAuthBrowserInputs(
          url: url,
          callbackUrlScheme: callbackUrlScheme,
          prefersEphemeralWebBrowserSession: prefersEphemeral
        ))
        guard let state = createParams.value?.state else {
          throw ClerkClientError(message: "Missing state in test.")
        }
        return try makeHostedAuthCallbackUrl(
          redirectUrl: "myapp:///hosted-auth-callback",
          state: state,
          rotatingTokenNonce: "nonce_123",
          createdSessionId: Session.mock2.id
        )
      }
    )

    #expect(session.id == Session.mock2.id)
    #expect(Clerk.shared.client == activatedClient)
    #expect(createParams.value?.redirectUrl == "myapp:///hosted-auth-callback")
    #expect(createParams.value?.mode == .signUp)
    #expect(redeemParams.value?.rotatingTokenNonce == "nonce_123")
    #expect(setActiveCall.value == HostedAuthSetActiveCall(sessionId: Session.mock2.id, organizationId: nil))
    #expect(try browserInputs.value == HostedAuthBrowserInputs(
      url: #require(URL(string: "https://accounts.example.com/sign-in")),
      callbackUrlScheme: "myapp",
      prefersEphemeralWebBrowserSession: false
    ))
  }

  @Test
  func overlappingStartIsRejectedBeforeCreatingAnotherTransfer() async throws {
    let createCalls = LockIsolated(0)
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    var redeemedClient = Client.mock
    redeemedClient.sessions = [.mock]
    redeemedClient.lastActiveSessionId = Session.mock.id

    let hostedAuthService = MockHostedAuthService(
      create: { params in
        createCalls.withValue { $0 += 1 }
        createParams.setValue(params)
        return HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
      },
      redeem: { _ in
        ClientServiceResponse(client: redeemedClient, requestSequence: nil, serverDate: nil)
      }
    )
    configureHostedAuthForTesting(
      hostedAuthService: hostedAuthService,
      sessionService: MockSessionService(),
      initialClient: .mockSignedOut
    )

    let auth = Clerk.shared.auth
    let session = try await auth.performHostedAuth(
      mode: nil,
      redirectUrl: "myapp://callback",
      prefersEphemeralWebBrowserSession: false,
      webAuthentication: { _, _, _ in
        do {
          _ = try await auth.performHostedAuth(
            mode: nil,
            redirectUrl: "myapp://callback",
            prefersEphemeralWebBrowserSession: false,
            webAuthentication: { _, _, _ in
              throw ClerkClientError(message: "Unexpected second browser launch.")
            }
          )
          Issue.record("Expected overlapping hosted auth to throw")
        } catch let error as ClerkClientError {
          #expect(error.message == "A hosted authentication session is already in progress.")
          #expect(createCalls.value == 1)
        }

        return try makeHostedAuthCallbackUrl(
          redirectUrl: "myapp://callback",
          state: #require(createParams.value?.state),
          rotatingTokenNonce: "nonce_123",
          createdSessionId: Session.mock.id
        )
      }
    )
    #expect(session.id == Session.mock.id)
  }

  @Test
  func cancellationPropagatesWithoutRedeemingOrActivating() async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    let redeemCalled = LockIsolated(false)
    let setActiveCalled = LockIsolated(false)
    let initialClient = Client.mockSignedOut
    let hostedAuthService = MockHostedAuthService(
      create: { params in
        createParams.setValue(params)
        return HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
      },
      redeem: { _ in
        redeemCalled.setValue(true)
        return ClientServiceResponse(client: .mock, requestSequence: nil, serverDate: nil)
      }
    )
    let sessionService = MockSessionService(setActive: { _, _ in
      setActiveCalled.setValue(true)
    })
    configureHostedAuthForTesting(
      hostedAuthService: hostedAuthService,
      sessionService: sessionService,
      initialClient: initialClient
    )

    do {
      _ = try await Clerk.shared.auth.performHostedAuth(
        mode: nil,
        redirectUrl: "myapp://callback",
        prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in throw CancellationError() }
      )
      Issue.record("Expected hosted auth cancellation to throw")
    } catch is CancellationError {
      #expect(createParams.value?.redirectUrl == "myapp://callback")
      #expect(!redeemCalled.value)
      #expect(!setActiveCalled.value)
      #expect(Clerk.shared.client == initialClient)
    } catch {
      Issue.record("Expected CancellationError, got \(error)")
    }
  }

  @Test
  func missingCallbackSessionDoesNotApplyClientOrActivateAnotherSession() async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    let setActiveCalled = LockIsolated(false)
    let initialClient = Client.mockSignedOut
    let hostedAuthService = MockHostedAuthService(
      create: { params in
        createParams.setValue(params)
        return HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
      },
      redeem: { _ in
        ClientServiceResponse(client: .mock, requestSequence: nil, serverDate: nil)
      }
    )
    let sessionService = MockSessionService(setActive: { _, _ in
      setActiveCalled.setValue(true)
    })
    configureHostedAuthForTesting(
      hostedAuthService: hostedAuthService,
      sessionService: sessionService,
      initialClient: initialClient
    )

    do {
      _ = try await Clerk.shared.auth.performHostedAuth(
        mode: nil,
        redirectUrl: "myapp://callback",
        prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in
          guard let state = createParams.value?.state else {
            throw ClerkClientError(message: "Missing state in test.")
          }
          return try makeHostedAuthCallbackUrl(
            redirectUrl: "myapp://callback",
            state: state,
            rotatingTokenNonce: "nonce_123",
            createdSessionId: "sess_callback"
          )
        }
      )
      Issue.record("Expected missing callback session to throw")
    } catch let error as ClerkClientError {
      #expect(error.message == "Hosted auth completion did not include the created session.")
      #expect(!setActiveCalled.value)
      #expect(Clerk.shared.client == initialClient)
    } catch {
      Issue.record("Expected ClerkClientError, got \(error)")
    }
  }

  @Test
  func clientChangeDuringActivationDoesNotReturnStaleSession() async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    var redeemedClient = Client.mock
    redeemedClient.sessions = [.mock]
    redeemedClient.lastActiveSessionId = Session.mock.id
    let hostedAuthService = MockHostedAuthService(
      create: { params in
        createParams.setValue(params)
        return HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
      },
      redeem: { _ in
        ClientServiceResponse(client: redeemedClient, requestSequence: nil, serverDate: nil)
      }
    )
    let sessionService = MockSessionService(setActive: { _, _ in
      Clerk.shared.client = .mockSignedOut
    })
    configureHostedAuthForTesting(
      hostedAuthService: hostedAuthService,
      sessionService: sessionService,
      initialClient: .mockSignedOut
    )

    do {
      _ = try await Clerk.shared.auth.performHostedAuth(
        mode: nil,
        redirectUrl: "myapp://callback",
        prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in
          let state = try #require(createParams.value?.state)
          return try makeHostedAuthCallbackUrl(
            redirectUrl: "myapp://callback",
            state: state,
            rotatingTokenNonce: "nonce_123",
            createdSessionId: Session.mock.id
          )
        }
      )
      Issue.record("Expected client change during activation to throw")
    } catch let error as ClerkClientError {
      #expect(error.message == "Hosted auth completion could not activate the created session.")
      #expect(Clerk.shared.client == .mockSignedOut)
    }
  }
}

private struct HostedAuthBrowserInputs: Equatable {
  let url: URL
  let callbackUrlScheme: String
  let prefersEphemeralWebBrowserSession: Bool
}

private struct HostedAuthSetActiveCall: Equatable {
  let sessionId: String
  let organizationId: String?
}

@MainActor
private func configureHostedAuthForTesting(
  hostedAuthService: some HostedAuthServiceProtocol,
  sessionService: some SessionServiceProtocol,
  initialClient: Client
) {
  configureClerkForTesting()
  Clerk.shared.dependencies = MockDependencyContainer(
    apiClient: Clerk.shared.dependencies.apiClient,
    hostedAuthService: hostedAuthService,
    sessionService: sessionService
  )
  Clerk.shared.client = initialClient
}

private func makeHostedAuthCallbackUrl(
  redirectUrl: String,
  state: String,
  rotatingTokenNonce: String,
  createdSessionId: String
) throws -> URL {
  guard var components = URLComponents(string: redirectUrl) else {
    throw ClerkClientError(message: "Invalid redirect URL in test.")
  }
  components.queryItems = [
    URLQueryItem(name: "state", value: state),
    URLQueryItem(name: "rotating_token_nonce", value: rotatingTokenNonce),
    URLQueryItem(name: "created_session_id", value: createdSessionId),
  ]
  guard let url = components.url else {
    throw ClerkClientError(message: "Invalid callback URL in test.")
  }
  return url
}
