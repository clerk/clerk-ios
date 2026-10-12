@_spi(FrameworkIntegration) @testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Observation
import Testing

@MainActor
@Suite(.serialized)
struct SessionTokenAuthorizationTests {
  init() {
    configureClerkForTesting()
  }

  @Test(arguments: [false, true])
  func refreshUpdatesAuthorizationAndObservation(previouslyAllowed: Bool) async throws {
    let now = Int(Date.now.timeIntervalSince1970)
    var session = Session.mock
    session.lastActiveToken = try token(issuedAt: now - 60, allowed: previouslyAllowed)
    let refreshed = try token(issuedAt: now, allowed: !previouslyAllowed)
    let clerk = try await configure(session: session, response: refreshed)
    session = try #require(clerk.session)
    let didChange = LockIsolated(false)
    let initialValue = withObservationTracking {
      clerk.has(feature: "widgets")
    } onChange: {
      didChange.setValue(true)
    }
    #expect(initialValue == previouslyAllowed)
    #expect(clerk.has(plan: "gold") == previouslyAllowed)
    #expect(clerk.has(reverification: .strict) == previouslyAllowed)

    let jwt = try await clerk.auth.getToken(.init(skipCache: true))

    #expect(jwt == refreshed.jwt)
    #expect(clerk.has(feature: "widgets") == !previouslyAllowed)
    #expect(clerk.has(plan: "gold") == !previouslyAllowed)
    #expect(clerk.has(reverification: .strict) == !previouslyAllowed)
    #expect(didChange.value)
    session.lastActiveToken = refreshed
    #expect(clerk.session == session)
    await clerk.waitForCacheWrites()
    #expect(try clerk.dependencies.identityStore.load()?.client?.currentSession == session)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 100))
  }

  @Test(arguments: [false, true])
  func currentSessionTokenIsReusedWithoutAnotherRequest(rotateDeviceToken: Bool) async throws {
    let now = Int(Date.now.timeIntervalSince1970)
    var session = Session.mock
    session.lastActiveToken = try token(issuedAt: now - 60)
    let cached = try token(issuedAt: now, allowed: true)
    session.lastActiveToken = cached
    let clerk = try await configure(session: session, response: nil)

    if rotateDeviceToken {
      #expect(try await clerk.setDeviceToken("rotated-device-token", expected: "test-device-token"))
    }

    #expect(try await clerk.auth.getToken() == cached.jwt)
    #expect(clerk.session?.lastActiveToken == cached)
    #expect(clerk.has(feature: "widgets"))
  }

  @Test
  func emptyOrganizationIdKeepsTheCurrentToken() async throws {
    let now = Int(Date.now.timeIntervalSince1970)
    var session = Session.mock
    let cached = try token(issuedAt: now, allowed: true)
    session.lastActiveToken = cached
    let fetches = LockIsolated(0)
    let clerk = try await configure(session: session, response: nil, onFetch: { _ in fetches.withValue { $0 += 1 } })
    var incoming = try #require(clerk.client)
    incoming.sessions[0].lastActiveOrganizationId = ""
    clerk.applyResponseClient(incoming)

    #expect(try await clerk.auth.getToken() == cached.jwt)
    #expect(fetches.value == 0)
  }

  enum RejectedToken: CaseIterable {
    case template, anotherSession, anotherOrganization, missingSessionId, malformed
  }

  @Test(arguments: RejectedToken.allCases)
  func unrelatedTokensDoNotChangeTheSession(scenario: RejectedToken) async throws {
    let now = Int(Date.now.timeIntervalSince1970)
    var session = Session.mock
    session.lastActiveToken = try token(issuedAt: now - 60)
    let response: TokenResource = switch scenario {
    case .template:
      try token(issuedAt: now, allowed: true)
    case .anotherSession:
      try token(sessionId: "other-session", issuedAt: now, allowed: true)
    case .anotherOrganization:
      try token(organizationId: "other-organization", issuedAt: now, allowed: true)
    case .missingSessionId:
      try TokenResource(jwt: testJWT(claims: ["iat": now, "exp": now + 3600, "fea": "u:widgets"]))
    case .malformed:
      TokenResource(jwt: "not-a-jwt")
    }
    let clerk = try await configure(session: session, response: response)
    let original = clerk.client

    _ = try await clerk.auth.getToken(.init(template: scenario == .template ? "custom" : nil, skipCache: true))

    #expect(clerk.client == original)
    #expect(!clerk.has(feature: "widgets"))
  }

  enum RefreshBoundary: CaseIterable {
    case signedOut, ended, organizationChanged, organizationChangedBack, reactivated, clientChanged, deviceTokenChanged, invalidated
  }

  @Test(arguments: RefreshBoundary.allCases)
  func lateRefreshDoesNotOverwriteChangedIdentity(boundary: RefreshBoundary) async throws {
    let now = Int(Date.now.timeIntervalSince1970)
    var session = Session.mock
    session.lastActiveToken = try token(issuedAt: now - 60)
    let response = try token(issuedAt: now, allowed: true)
    let clerk = try await configure(session: session, response: response, beforeResponse: {
      let clerk = Clerk.shared
      var client = try #require(clerk.client)
      switch boundary {
      case .signedOut:
        try clerk.identityController.clearIdentity()
      case .ended:
        client.sessions[0].status = .ended
        clerk.applyResponseClient(client)
      case .organizationChanged:
        client.sessions[0].lastActiveOrganizationId = "other-organization"
        clerk.applyResponseClient(client)
      case .organizationChangedBack:
        var differentOrganization = client
        differentOrganization.sessions[0].lastActiveOrganizationId = "other-organization"
        clerk.applyResponseClient(differentOrganization)
        clerk.applyResponseClient(client)
      case .reactivated:
        var ended = client
        ended.sessions[0].status = .ended
        clerk.applyResponseClient(ended)
        clerk.applyResponseClient(client)
      case .clientChanged:
        client.id = "other-client"
        clerk.applyResponseClient(client)
      case .deviceTokenChanged:
        try clerk.identityController.adoptDeviceToken("other-device-token")
        clerk.applyResponseClient(client)
      case .invalidated:
        Clerk.shared.identityController.invalidateSessionTokens(sessionId: session.id)
      }
    })

    _ = try await clerk.auth.getToken(.init(skipCache: true))

    #expect(clerk.session?.lastActiveToken != response)
    #expect(!clerk.has(feature: "widgets"))
    switch boundary {
    case .signedOut:
      #expect(clerk.client == nil)
    case .ended:
      #expect(clerk.client?.sessions.first?.status == .ended)
    case .organizationChanged:
      #expect(clerk.session?.lastActiveOrganizationId == "other-organization")
    case .organizationChangedBack, .reactivated:
      #expect(clerk.session?.lastActiveOrganizationId == nil)
      #expect(clerk.session?.status == .active)
    case .clientChanged:
      #expect(clerk.client?.id == "other-client")
    case .deviceTokenChanged:
      #expect(clerk.identityController.currentDeviceToken == "other-device-token")
    case .invalidated:
      #expect(!clerk.identityController.canReuseSessionToken(sessionId: session.id))
    }
  }

  @Test(arguments: [false, true], [false, true])
  func unchangedClientResponseDoesNotUndoInvalidation(minterEnabled: Bool, invalidateAll: Bool) async throws {
    let now = Int(Date.now.timeIntervalSince1970)
    var session = Session.mock
    session.lastActiveToken = try token(issuedAt: now - 1)
    let refreshed = try token(issuedAt: now, allowed: true)
    let count = LockIsolated(0)
    let params = LockIsolated<SessionTokenRequestParams?>(nil)
    let clerk = try await configure(session: session, response: refreshed, onFetch: {
      count.withValue { $0 += 1 }
      params.setValue($0)
    })
    var environment = Clerk.Environment.mock
    environment.authConfig.sessionMinter = minterEnabled
    clerk.environment = environment
    let retained = try #require(clerk.session)
    if invalidateAll {
      clerk.identityController.invalidateAllSessionTokens()
    } else {
      clerk.identityController.invalidateSessionTokens(sessionId: session.id)
    }
    clerk.applyResponseClient(clerk.client)
    #expect(clerk.session?.lastActiveToken == retained.lastActiveToken)
    #expect(!clerk.identityController.canReuseSessionToken(sessionId: session.id))

    #expect(try await retained.getToken() == refreshed.jwt)
    #expect(try await clerk.auth.getToken() == refreshed.jwt)
    #expect(count.value == 1)
    #expect(params.value?.token == (minterEnabled ? retained.lastActiveToken?.jwt : nil))
    #expect(params.value?.forceOrigin == (minterEnabled ? "true" : nil))
    #expect(clerk.has(feature: "widgets"))
    #expect(retained.lastActiveToken != clerk.session?.lastActiveToken)
  }

  @Test(arguments: [false, true], [false, true])
  func deviceTokenRotationDoesNotUndoInvalidation(minterEnabled: Bool, invalidateAll: Bool) async throws {
    let now = Int(Date.now.timeIntervalSince1970)
    var session = Session.mock
    session.lastActiveToken = try token(issuedAt: now - 1)
    let refreshed = try token(issuedAt: now, allowed: true)
    let count = LockIsolated(0)
    let params = LockIsolated<SessionTokenRequestParams?>(nil)
    let clerk = try await configure(session: session, response: refreshed, onFetch: {
      count.withValue { $0 += 1 }
      params.setValue($0)
    })
    var environment = Clerk.Environment.mock
    environment.authConfig.sessionMinter = minterEnabled
    clerk.environment = environment
    if invalidateAll {
      clerk.identityController.invalidateAllSessionTokens()
    } else {
      clerk.identityController.invalidateSessionTokens(sessionId: session.id)
    }

    #expect(try await clerk.setDeviceToken("rotated-device-token", expected: "test-device-token"))
    #expect(clerk.session?.lastActiveToken == session.lastActiveToken)
    #expect(!clerk.identityController.canReuseSessionToken(sessionId: session.id))

    #expect(try await clerk.auth.getToken() == refreshed.jwt)
    #expect(try await clerk.auth.getToken() == refreshed.jwt)
    #expect(count.value == 1)
    #expect(params.value?.token == (minterEnabled ? session.lastActiveToken?.jwt : nil))
    #expect(params.value?.forceOrigin == (minterEnabled ? "true" : nil))
    #expect(clerk.has(reverification: .strict))
  }

  @Test
  func successfulRefreshCanRevalidateAnIdenticalToken() async throws {
    let now = Int(Date.now.timeIntervalSince1970)
    var session = Session.mock
    let response = try token(issuedAt: now, allowed: true)
    session.lastActiveToken = response
    let count = LockIsolated(0)
    let clerk = try await configure(session: session, response: response, onFetch: { _ in count.withValue { $0 += 1 } })
    clerk.identityController.invalidateSessionTokens(sessionId: session.id)

    #expect(try await clerk.auth.getToken() == response.jwt)
    #expect(try await clerk.auth.getToken() == response.jwt)
    #expect(count.value == 1)
    #expect(clerk.identityController.canReuseSessionToken(sessionId: session.id))
  }

  @Test
  func refreshingAnotherActiveSessionDoesNotSwitchTheCurrentSession() async throws {
    let now = Int(Date.now.timeIntervalSince1970)
    var session = Session.mock
    session.lastActiveToken = try token(issuedAt: now - 60)
    let response = try token(issuedAt: now, allowed: true)
    let clerk = try await configure(session: session, response: response)
    var client = try #require(clerk.client)
    client.sessions.append(.mock2)
    client.lastActiveSessionId = Session.mock2.id
    clerk.applyResponseClient(client)
    let selectedSession = clerk.session

    _ = try await session.getToken(.init(skipCache: true))

    #expect(clerk.session == selectedSession)
    #expect(clerk.client?.sessions.first?.lastActiveToken == response)
  }

  @Test
  func invalidatingOneSessionPreservesOtherSessionsAndTheirTemplates() async throws {
    let now = Int(Date.now.timeIntervalSince1970)
    var session = Session.mock
    session.lastActiveToken = try token(issuedAt: now - 1)
    let refreshed = try token(issuedAt: now, allowed: true)
    let calls = LockIsolated(0)
    let clerk = try await configure(session: session, response: refreshed, onFetch: { _ in calls.withValue { $0 += 1 } })
    var other = Session.mock2
    let otherToken = try token(sessionId: other.id, issuedAt: now, allowed: true)
    other.lastActiveToken = otherToken
    var client = try #require(clerk.client)
    client.sessions.append(other)
    clerk.applyResponseClient(client)
    SessionTemplateTokensCache.shared.insertToken(otherToken, cacheKey: other.tokenCacheKey(template: "firebase"))
    clerk.identityController.invalidateSessionTokens(sessionId: session.id)

    #expect(try await other.getToken() == otherToken.jwt)
    #expect(try await other.getToken(.init(template: "firebase")) == otherToken.jwt)
    #expect(calls.value == 0)
    #expect(try await session.getToken() == refreshed.jwt)
    #expect(calls.value == 1)
    #expect(clerk.session?.id == session.id)
    #expect(clerk.client?.sessions.first(where: { $0.id == other.id })?.lastActiveToken == otherToken)
  }

  @Test(arguments: [false, true])
  func clientResponsesPreserveRefreshedTokens(useNetworkResponse: Bool) async throws {
    let now = Int(Date.now.timeIntervalSince1970)
    var session = Session.mock
    session.lastActiveToken = try token(issuedAt: now - 60)
    let refreshed = try token(issuedAt: now, allowed: true)
    let clerk = try await configure(session: session, response: refreshed)
    var incoming = try #require(clerk.client)
    incoming.sessions[0].user?.firstName = "Updated profile"
    _ = try await clerk.auth.getToken(.init(skipCache: true))

    if useNetworkResponse {
      try await clerk.identityController.applyNetworkResponse(ClientSyncResponseContext(
        update: .client(incoming),
        deviceTokenUpdate: .absent,
        requestDeviceToken: clerk.identityController.currentDeviceToken,
        serverDate: Date(timeIntervalSince1970: 200),
        isCanonicalClientRequest: true,
        clientResponseGeneration: clerk.clientResponseGeneration,
        responseSequence: 1
      ))
    } else {
      clerk.applyResponseClient(incoming, serverDate: Date(timeIntervalSince1970: 200))
    }

    #expect(clerk.session?.lastActiveToken == refreshed)
    #expect(clerk.has(feature: "widgets"))
    #expect(clerk.user?.firstName == "Updated profile")
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
    await clerk.waitForCacheWrites()
    #expect(try clerk.dependencies.identityStore.load()?.client?.currentSession?.lastActiveToken == refreshed)
  }

  @Test(arguments: [0, 1], [false, true])
  func clientResponseCanReplaceTheTokenOrRemoveIt(issuedAtOffset: Int, useNetworkResponse: Bool) async throws {
    let now = Int(Date.now.timeIntervalSince1970)
    var session = Session.mock
    session.lastActiveToken = try token(issuedAt: now - 60)
    let refreshed = try token(issuedAt: now, allowed: true)
    let clerk = try await configure(session: session, response: refreshed)
    _ = try await clerk.auth.getToken(.init(skipCache: true))
    var incoming = try #require(clerk.client)
    let newer = try token(issuedAt: now + issuedAtOffset)
    incoming.sessions[0].lastActiveToken = newer

    if useNetworkResponse {
      try await clerk.identityController.applyNetworkResponse(ClientSyncResponseContext(
        update: .client(incoming),
        deviceTokenUpdate: .absent,
        requestDeviceToken: clerk.identityController.currentDeviceToken,
        serverDate: Date(timeIntervalSince1970: 200),
        isCanonicalClientRequest: true,
        clientResponseGeneration: clerk.clientResponseGeneration,
        responseSequence: 1
      ))
    } else {
      clerk.applyResponseClient(incoming)
    }

    #expect(clerk.session?.lastActiveToken == newer)
    #expect(!clerk.has(feature: "widgets"))
    #expect(try await clerk.auth.getToken() == newer.jwt)
    #expect(clerk.session?.lastActiveToken == newer)
    #expect(!clerk.has(feature: "widgets"))
    #expect(!clerk.has(plan: "gold"))
    #expect(!clerk.has(reverification: .strict))
    incoming.sessions[0].lastActiveToken = nil

    clerk.applyResponseClient(incoming)

    #expect(clerk.session?.lastActiveToken == nil)
  }

  @Test(arguments: [false, true])
  func sameTimestampRefreshReplacesAcceptedClientToken(previouslyAllowed: Bool) async throws {
    let now = Int(Date.now.timeIntervalSince1970)
    var retainedSession = Session.mock
    retainedSession.lastActiveToken = try token(issuedAt: now - 60)
    let refreshed = try token(issuedAt: now, allowed: !previouslyAllowed)
    let clerk = try await configure(session: retainedSession, response: refreshed)
    var incoming = try #require(clerk.client)
    incoming.sessions[0].lastActiveToken = try token(issuedAt: now, allowed: previouslyAllowed)
    clerk.applyResponseClient(incoming)
    #expect(clerk.has(feature: "widgets") == previouslyAllowed)

    #expect(try await clerk.auth.getToken(.init(skipCache: true)) == refreshed.jwt)
    #expect(try await retainedSession.getToken() == refreshed.jwt)
    #expect(clerk.session?.lastActiveToken == refreshed)
    #expect(clerk.has(feature: "widgets") == !previouslyAllowed)
    #expect(clerk.has(plan: "gold") == !previouslyAllowed)
    #expect(clerk.has(reverification: .strict) == !previouslyAllowed)
  }

  private func configure(
    session: Session,
    response: TokenResource?,
    onFetch: @escaping @MainActor (SessionTokenRequestParams?) -> Void = { _ in },
    beforeResponse: @escaping @MainActor () async throws -> Void = {}
  ) async throws -> Clerk {
    await SessionTokenFetcher.shared.reset()
    SessionTemplateTokensCache.shared.clear()
    let clerk = Clerk.shared
    let transport = FakeTransport.mockDefaults()
    transport.stubSessionToken { _, _, params in
      onFetch(params)
      try await beforeResponse()
      return response
    }
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
    )
    clerk.client = nil
    var client = Client.mock
    client.sessions = [session]
    client.lastActiveSessionId = session.id
    try clerk.seedIdentity(deviceToken: "test-device-token", client: client, serverDate: Date(timeIntervalSince1970: 100))
    return clerk
  }

  private func token(
    sessionId: String = Session.mock.id,
    organizationId: String? = nil,
    issuedAt: Int,
    allowed: Bool = false
  ) throws -> TokenResource {
    var claims: [String: Any] = [
      "sid": sessionId,
      "iat": issuedAt,
      "exp": issuedAt + 3600,
      "fea": allowed ? "u:widgets" : "",
      "pla": allowed ? "u:gold" : "",
      "fva": [allowed ? 0 : 30, -1],
    ]
    if let organizationId {
      claims["org_id"] = organizationId
    }
    return try TokenResource(jwt: testJWT(claims: claims))
  }
}
