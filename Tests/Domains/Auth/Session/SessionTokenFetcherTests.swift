@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct SessionTokenFetcherTests {
  init() {
    configureClerkForTesting()
    Clerk.shared.cleanupManagers()
  }

  struct FetchTokenScenario: Codable, Equatable {
    let template: String?
  }

  @Test(
    arguments: [
      FetchTokenScenario(template: nil),
      FetchTokenScenario(template: "firebase"),
    ]
  )
  func fetchTokenUsesSessionServiceFetchToken(
    scenario: FetchTokenScenario
  ) async throws {
    await SessionTokensCache.shared.clear()
    let session = Session.mock
    let captured = LockIsolated<(
      sessionId: String,
      template: String?,
      params: SessionTokenRequestParams?
    )?>(nil)
    let service = MockSessionService(fetchToken: { sessionId, template, params in
      captured.setValue((sessionId: sessionId, template: template, params: params))
      return .mock
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    _ = try await SessionTokenFetcher.shared.fetchToken(
      session,
      options: .init(template: scenario.template, skipCache: true)
    )

    let values = try #require(captured.value)
    #expect(values.sessionId == session.id)
    #expect(values.template == scenario.template)
    if scenario.template == nil {
      #expect(values.params?.organizationId == "")
      #expect(values.params?.token == nil)
      #expect(values.params?.forceOrigin == nil)
    } else {
      #expect(values.params == nil)
    }
  }

  @Test
  func fetchTokenCachesFetchedToken() async throws {
    await SessionTokensCache.shared.clear()
    let session = Session.mock
    let template = UUID().uuidString
    let tokenResource = TokenResource(jwt: "jwt_123")
    let service = MockSessionService(fetchToken: { _, _, _ in
      tokenResource
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    _ = try await SessionTokenFetcher.shared.fetchToken(
      session,
      options: .init(template: template, skipCache: true)
    )

    let cachedToken = await SessionTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: template)
    )
    #expect(cachedToken == tokenResource)
  }

  @Test
  func sessionMinterUsesLatestSessionTokenAndForcesOrigin() async throws {
    await SessionTokensCache.shared.clear()
    let staleSession = Session.mock
    var currentSession = staleSession
    currentSession.lastActiveOrganizationId = "org_test"
    currentSession.lastActiveToken = try token(
      sessionId: currentSession.id,
      organizationId: currentSession.lastActiveOrganizationId,
      originIssuedAt: 100,
      issuedAt: 100,
      signature: "previous"
    )
    configureCurrentState(session: currentSession, sessionMinterEnabled: true)

    let captured = LockIsolated<SessionTokenRequestParams?>(nil)
    let service = MockSessionService(fetchToken: { _, _, params in
      captured.setValue(params)
      return try token(
        sessionId: currentSession.id,
        organizationId: currentSession.lastActiveOrganizationId,
        originIssuedAt: 200,
        issuedAt: 200,
        signature: "response"
      )
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    _ = try await SessionTokenFetcher.shared.fetchToken(
      staleSession,
      options: .init(skipCache: true)
    )

    let params = try #require(captured.value)
    #expect(params.organizationId == "org_test")
    #expect(params.token == currentSession.lastActiveToken?.jwt)
    #expect(params.forceOrigin == "true")
  }

  @Test
  func sessionMinterOmitsPreviousTokenOnFirstMint() async throws {
    await SessionTokensCache.shared.clear()
    let session = Session.mock
    configureCurrentState(session: session, sessionMinterEnabled: true)

    let captured = LockIsolated<SessionTokenRequestParams?>(nil)
    let service = MockSessionService(fetchToken: { _, _, params in
      captured.setValue(params)
      return .mock
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    _ = try await SessionTokenFetcher.shared.fetchToken(session)

    let params = try #require(captured.value)
    #expect(params.token == nil)
    #expect(params.forceOrigin == nil)
  }

  @Test
  func disabledSessionMinterDoesNotPassTokenOrForceOrigin() async throws {
    await SessionTokensCache.shared.clear()
    var session = Session.mock
    session.lastActiveOrganizationId = "org_test"
    session.lastActiveToken = try token(
      sessionId: session.id,
      organizationId: session.lastActiveOrganizationId,
      originIssuedAt: 100,
      issuedAt: 100
    )
    configureCurrentState(session: session, sessionMinterEnabled: false)

    let captured = LockIsolated<SessionTokenRequestParams?>(nil)
    let service = MockSessionService(fetchToken: { _, _, params in
      captured.setValue(params)
      return .mock
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    _ = try await SessionTokenFetcher.shared.fetchToken(
      session,
      options: .init(skipCache: true)
    )

    let params = try #require(captured.value)
    #expect(params.organizationId == "org_test")
    #expect(params.token == nil)
    #expect(params.forceOrigin == nil)
  }

  @Test
  func concurrentForcedRefreshesCannotRollBackCanonicalToken() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    var session = Session.mock
    session.lastActiveToken = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 50,
      issuedAt: 50,
      signature: "previous"
    )
    let staleResponse = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 100,
      issuedAt: 100,
      signature: "stale"
    )
    let freshResponse = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 200,
      issuedAt: 200,
      signature: "fresh"
    )
    configureCurrentState(session: session, sessionMinterEnabled: true)

    let callCount = LockIsolated(0)
    let service = MockSessionService(fetchToken: { _, _, _ in
      let callIndex = callCount.withValue { count in
        defer { count += 1 }
        return count
      }
      if callIndex == 0 {
        try await Task.sleep(for: .milliseconds(100))
        return staleResponse
      }
      return freshResponse
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let first = Task {
      try await SessionTokenFetcher.shared.getToken(
        session,
        options: .init(skipCache: true)
      )
    }
    let deadline = ContinuousClock.now + .seconds(1)
    while callCount.value == 0, ContinuousClock.now < deadline {
      await Task.yield()
    }
    let second = Task {
      try await SessionTokenFetcher.shared.getToken(
        session,
        options: .init(skipCache: true)
      )
    }

    let firstResult = try await first.value
    let secondResult = try await second.value
    let cachedToken = await SessionTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: nil)
    )

    #expect(callCount.value == 2)
    #expect(firstResult == staleResponse)
    #expect(secondResult == freshResponse)
    #expect(cachedToken == freshResponse)
  }

  private func configureCurrentState(
    session: Session,
    sessionMinterEnabled: Bool
  ) {
    var environment = Clerk.Environment.mock
    environment.authConfig.sessionMinter = sessionMinterEnabled
    Clerk.shared.environment = environment

    var client = Client.mock
    client.sessions = [session]
    client.lastActiveSessionId = session.id
    Clerk.shared.client = client
  }

  private func token(
    sessionId: String,
    organizationId: String?,
    originIssuedAt: Int,
    issuedAt: Int,
    signature: String = "signature"
  ) throws -> TokenResource {
    let header: [String: Any] = [
      "alg": "none",
      "typ": "JWT",
      "oiat": originIssuedAt,
    ]
    var claims: [String: Any] = [
      "sid": sessionId,
      "iat": issuedAt,
      "exp": 4_000_000_000,
    ]
    if let organizationId {
      claims["org_id"] = organizationId
    }
    return try TokenResource(
      jwt: testJWT(header: header, claims: claims, signature: signature)
    )
  }
}
