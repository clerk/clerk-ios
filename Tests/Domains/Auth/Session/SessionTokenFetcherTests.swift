@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct SessionServiceAndTokenFetcherTests {
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
  func templateTokenCacheIsPartitionedByActiveOrganization() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    let template = "firebase"
    var previousSession = Session.mock
    previousSession.lastActiveOrganizationId = "org_previous"
    let previousToken = try token(
      sessionId: previousSession.id,
      organizationId: previousSession.lastActiveOrganizationId,
      originIssuedAt: 100,
      issuedAt: 100,
      signature: "previous"
    )
    await SessionTokensCache.shared.insertToken(
      previousToken,
      cacheKey: previousSession.tokenCacheKey(template: template)
    )

    var updatedSession = previousSession
    updatedSession.lastActiveOrganizationId = "org_updated"
    configureCurrentState(session: updatedSession, sessionMinterEnabled: true)
    let updatedToken = try token(
      sessionId: updatedSession.id,
      organizationId: updatedSession.lastActiveOrganizationId,
      originIssuedAt: 200,
      issuedAt: 200,
      signature: "updated"
    )
    let callCount = LockIsolated(0)
    let service = MockSessionService(fetchToken: { _, _, _ in
      callCount.withValue { $0 += 1 }
      return updatedToken
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let result = try await SessionTokenFetcher.shared.getToken(
      previousSession,
      options: .init(template: template)
    )

    #expect(result == updatedToken)
    #expect(callCount.value == 1)
    #expect(
      previousSession.tokenCacheKey(template: template)
        != updatedSession.tokenCacheKey(template: template)
    )
    #expect(await SessionTokensCache.shared.getToken(
      cacheKey: previousSession.tokenCacheKey(template: template)
    ) == previousToken)
    #expect(await SessionTokensCache.shared.getToken(
      cacheKey: updatedSession.tokenCacheKey(template: template)
    ) == updatedToken)
  }

  @Test
  func invalidationPreventsInFlightResponseFromRestoringCachedToken() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    let session = Session.mock
    let response = TokenResource(jwt: "late.jwt.response")
    configureCurrentState(session: session, sessionMinterEnabled: false)
    let generationBeforeRequest = await SessionTokensCache.shared.generation(
      sessionId: session.id
    )

    let requestGate = SessionTokenFetchGate()
    let service = MockSessionService(fetchToken: { _, _, _ in
      await requestGate.suspend()
      return response
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let request = Task {
      try await SessionTokenFetcher.shared.getToken(
        session,
        options: .init(skipCache: true)
      )
    }
    defer {
      request.cancel()
      Task { await requestGate.resume() }
    }

    try await waitForCondition(
      message: "Timed out waiting for the forced token task to be registered."
    ) {
      await SessionTokenFetcher.shared.forcedTokenTasks.isEmpty == false
    }
    let registeredTask = await SessionTokenFetcher.shared.forcedTokenTasks.values.first
    let registeredGeneration = try #require(registeredTask?.cacheGeneration)
    #expect(registeredGeneration == generationBeforeRequest)

    await SessionTokensCache.shared.removeTokens(sessionId: session.id)
    await requestGate.resume()

    #expect(try await request.value == response)
    #expect(await SessionTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: nil)
    ) == nil)
  }

  @Test
  func invalidatedInFlightTaskIsCancelledAndReplaced() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    let session = Session.mock
    let staleResponse = TokenResource(jwt: "stale.jwt.response")
    let freshResponse = TokenResource(jwt: "fresh.jwt.response")
    configureCurrentState(session: session, sessionMinterEnabled: false)

    let firstCallStarted = AsyncStream<Void>.makeStream(
      bufferingPolicy: .bufferingNewest(1)
    )
    let secondCallStarted = AsyncStream<Void>.makeStream(
      bufferingPolicy: .bufferingNewest(1)
    )
    defer {
      firstCallStarted.continuation.finish()
      secondCallStarted.continuation.finish()
    }

    let firstGate = SessionTokenFetchGate()
    let secondGate = SessionTokenFetchGate()
    let callCount = LockIsolated(0)
    let service = MockSessionService(fetchToken: { _, _, _ in
      let callIndex = callCount.withValue { count in
        defer { count += 1 }
        return count
      }

      switch callIndex {
      case 0:
        firstCallStarted.continuation.yield()
        await firstGate.suspend()
        return staleResponse
      case 1:
        secondCallStarted.continuation.yield()
        await secondGate.suspend()
        return freshResponse
      default:
        return TokenResource(jwt: "unexpected.jwt.response")
      }
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let first = Task {
      try await SessionTokenFetcher.shared.getToken(session)
    }
    defer {
      first.cancel()
      Task { await firstGate.resume() }
    }
    try await waitForSignal(
      firstCallStarted.stream,
      message: "Timed out waiting for the original token request to start."
    )

    let cacheKey = session.tokenCacheKey(template: nil)
    let originalTask = await SessionTokenFetcher.shared.tokenTasks[cacheKey]
    let originalTaskId = try #require(originalTask?.id)

    await SessionTokensCache.shared.removeTokens(sessionId: session.id)
    let currentGeneration = await SessionTokensCache.shared.generation(
      sessionId: session.id
    )

    let second = Task {
      try await SessionTokenFetcher.shared.getToken(session)
    }
    defer {
      second.cancel()
      Task { await secondGate.resume() }
    }
    try await waitForSignal(
      secondCallStarted.stream,
      message: "Timed out waiting for the replacement token request to start."
    )

    let replacementTask = await SessionTokenFetcher.shared.tokenTasks[cacheKey]
    #expect(replacementTask?.id != originalTaskId)
    #expect(replacementTask?.cacheGeneration == currentGeneration)

    await firstGate.resume()
    await #expect(throws: CancellationError.self) {
      try await first.value
    }

    await secondGate.resume()
    #expect(try await second.value == freshResponse)
    #expect(callCount.value == 2)
    #expect(await SessionTokensCache.shared.getToken(cacheKey: cacheKey) == freshResponse)
  }

  @Test
  func retainedSessionDoesNotRehydrateInvalidatedSnapshot() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    var session = Session.mock
    let snapshotToken = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 100,
      issuedAt: 100,
      signature: "snapshot"
    )
    let serverToken = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 200,
      issuedAt: 200,
      signature: "server"
    )
    session.lastActiveToken = snapshotToken
    configureCurrentState(session: session, sessionMinterEnabled: true)

    await SessionTokensCache.shared.removeTokens(sessionId: session.id)
    var signedOutClient = Client.mock
    signedOutClient.sessions = []
    signedOutClient.lastActiveSessionId = nil
    Clerk.shared.client = signedOutClient

    let callCount = LockIsolated(0)
    let capturedParams = LockIsolated<SessionTokenRequestParams?>(nil)
    let service = MockSessionService(fetchToken: { _, _, params in
      callCount.withValue { $0 += 1 }
      capturedParams.setValue(params)
      return serverToken
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let result = try await SessionTokenFetcher.shared.getToken(session)

    #expect(result == serverToken)
    #expect(callCount.value == 1)
    #expect(capturedParams.value?.token == nil)
    #expect(await SessionTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: nil)
    ) == serverToken)
  }

  @Test
  func nonActiveSessionDoesNotReturnExistingCachedToken() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    let session = Session.mock
    let cachedToken = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 100,
      issuedAt: 100,
      signature: "cached"
    )
    let serverToken = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 200,
      issuedAt: 200,
      signature: "server"
    )
    configureCurrentState(session: session, sessionMinterEnabled: true)

    await SessionTokensCache.shared.removeTokens(sessionId: session.id)
    await SessionTokensCache.shared.insertToken(
      cachedToken,
      cacheKey: session.tokenCacheKey(template: nil)
    )
    var signedOutClient = Client.mock
    signedOutClient.sessions = []
    signedOutClient.lastActiveSessionId = nil
    Clerk.shared.client = signedOutClient

    let callCount = LockIsolated(0)
    let capturedParams = LockIsolated<SessionTokenRequestParams?>(nil)
    let service = MockSessionService(fetchToken: { _, _, params in
      callCount.withValue { $0 += 1 }
      capturedParams.setValue(params)
      return serverToken
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let result = try await SessionTokenFetcher.shared.getToken(session)

    #expect(result == serverToken)
    #expect(callCount.value == 1)
    #expect(capturedParams.value?.token == nil)
  }

  @Test
  func concurrentNonActiveSessionFetchesShareRequest() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    let session = Session.mock
    let serverToken = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 200,
      issuedAt: 200,
      signature: "server"
    )
    configureCurrentState(session: session, sessionMinterEnabled: true)
    var signedOutClient = Client.mock
    signedOutClient.sessions = []
    signedOutClient.lastActiveSessionId = nil
    Clerk.shared.client = signedOutClient

    let callCount = LockIsolated(0)
    let requestStarted = AsyncStream<Void>.makeStream(
      bufferingPolicy: .bufferingNewest(1)
    )
    let secondCallerStarted = AsyncStream<Void>.makeStream(
      bufferingPolicy: .bufferingNewest(1)
    )
    let requestGate = SessionTokenFetchGate()
    defer {
      requestStarted.continuation.finish()
      secondCallerStarted.continuation.finish()
    }
    let service = MockSessionService(fetchToken: { _, _, _ in
      callCount.withValue { $0 += 1 }
      requestStarted.continuation.yield()
      await requestGate.suspend()
      try Task.checkCancellation()
      return serverToken
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let first = Task {
      try await SessionTokenFetcher.shared.getToken(session)
    }
    defer {
      first.cancel()
      Task { await requestGate.resume() }
    }
    try await waitForSignal(
      requestStarted.stream,
      message: "Timed out waiting for the first inactive-session fetch to start."
    )

    let cacheKey = session.tokenCacheKey(template: nil)
    let originalTask = await SessionTokenFetcher.shared.tokenTasks[cacheKey]
    let originalTaskId = try #require(originalTask?.id)

    let second = Task {
      secondCallerStarted.continuation.yield()
      return try await SessionTokenFetcher.shared.getToken(session)
    }
    defer { second.cancel() }
    try await waitForSignal(
      secondCallerStarted.stream,
      message: "Timed out waiting for the second inactive-session caller to start."
    )

    let sharedTask = await SessionTokenFetcher.shared.tokenTasks[cacheKey]
    #expect(sharedTask?.id == originalTaskId)
    #expect(sharedTask?.isCurrentActiveSession == false)

    await requestGate.resume()

    #expect(try await first.value == serverToken)
    #expect(try await second.value == serverToken)
    #expect(callCount.value == 1)
  }

  @Test
  func transitionedActiveSessionCanHydrateCanonicalSnapshot() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    var session = Session.mock
    let snapshotToken = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 200,
      issuedAt: 200,
      signature: "transitioned"
    )
    session.lastActiveToken = snapshotToken
    configureCurrentState(session: session, sessionMinterEnabled: true)
    await SessionTokensCache.shared.removeTokens(sessionId: session.id)

    let callCount = LockIsolated(0)
    let service = MockSessionService(fetchToken: { _, _, _ in
      callCount.withValue { $0 += 1 }
      return TokenResource(jwt: "unexpected.server.response")
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let result = try await SessionTokenFetcher.shared.getToken(session)

    #expect(result == snapshotToken)
    #expect(callCount.value == 0)
    #expect(await SessionTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: nil)
    ) == snapshotToken)
  }

  @Test
  func removeTokensClearsAllTokensForOnlyThatSession() async {
    let cache = SessionTokensCache()
    var session = Session.mock
    session.id = "sess_target"
    var otherSession = Session.mock
    otherSession.id = "sess_target2"

    await cache.insertToken(
      .init(jwt: "default.jwt"),
      cacheKey: session.tokenCacheKey(template: nil)
    )
    await cache.insertToken(
      .init(jwt: "template.jwt"),
      cacheKey: session.tokenCacheKey(template: "firebase")
    )
    await cache.insertToken(
      .init(jwt: "other.jwt"),
      cacheKey: otherSession.tokenCacheKey(template: nil)
    )

    await cache.removeTokens(sessionId: session.id)

    #expect(await cache.getToken(cacheKey: session.tokenCacheKey(template: nil)) == nil)
    #expect(await cache.getToken(cacheKey: session.tokenCacheKey(template: "firebase")) == nil)
    #expect(await cache.getToken(
      cacheKey: otherSession.tokenCacheKey(template: nil)
    )?.jwt == "other.jwt")
  }

  @Test
  func removeTokensRejectsWritesFromAnEarlierGeneration() async {
    let cache = SessionTokensCache()
    let session = Session.mock
    let generation = await cache.generation(sessionId: session.id)

    await cache.removeTokens(sessionId: session.id)
    let storeResult = await cache.storeIfFresher(
      .init(jwt: "late.jwt"),
      cacheKey: session.tokenCacheKey(template: nil),
      generation: generation
    )
    await cache.hydrate(
      .init(jwt: "late.snapshot.jwt"),
      cacheKey: session.tokenCacheKey(template: nil),
      generation: generation
    )

    #expect(storeResult?.canonicalToken == nil)
    #expect(await cache.getToken(cacheKey: session.tokenCacheKey(template: nil)) == nil)
  }

  @Test
  func clearRejectsWritesFromAnEarlierGeneration() async {
    let cache = SessionTokensCache()
    let session = Session.mock
    let generation = await cache.generation(sessionId: session.id)

    await cache.clear()
    let storeResult = await cache.storeIfFresher(
      .init(jwt: "late.jwt"),
      cacheKey: session.tokenCacheKey(template: nil),
      generation: generation
    )

    #expect(storeResult?.canonicalToken == nil)
    #expect(await cache.getToken(cacheKey: session.tokenCacheKey(template: nil)) == nil)
  }

  @Test
  func storingSameJWTDoesNotReportCanonicalTokenChange() async {
    await SessionTokensCache.shared.clear()
    let cacheKey = UUID().uuidString
    let tokenResource = TokenResource(jwt: "jwt_123")

    let initialStore = await SessionTokensCache.shared.storeIfFresher(
      tokenResource,
      cacheKey: cacheKey
    )
    let duplicateStore = await SessionTokensCache.shared.storeIfFresher(
      tokenResource,
      cacheKey: cacheKey
    )

    #expect(initialStore.didChangeCanonicalToken)
    #expect(duplicateStore.didChangeCanonicalToken == false)
  }

  @Test
  func malformedIncomingTokenDoesNotReplaceCanonicalToken() async throws {
    await SessionTokensCache.shared.clear()
    let cacheKey = UUID().uuidString
    let canonicalToken = try token(
      sessionId: "sess_test",
      organizationId: nil,
      originIssuedAt: 100,
      issuedAt: 100
    )
    let malformedToken = TokenResource(jwt: "malformed")
    await SessionTokensCache.shared.insertToken(
      canonicalToken,
      cacheKey: cacheKey
    )

    let storeResult = await SessionTokensCache.shared.storeIfFresher(
      malformedToken,
      cacheKey: cacheKey
    )
    let cachedToken = await SessionTokensCache.shared.getToken(cacheKey: cacheKey)

    #expect(storeResult.canonicalToken == canonicalToken)
    #expect(storeResult.didChangeCanonicalToken == false)
    #expect(cachedToken == canonicalToken)
  }

  @Test
  func hydrationDoesNotReplaceCanonicalTokenOnTimestampTie() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    var session = Session.mock
    let snapshotToken = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 100,
      issuedAt: 100,
      signature: "snapshot"
    )
    let mintedToken = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 100,
      issuedAt: 100,
      signature: "minted"
    )
    session.lastActiveToken = snapshotToken
    configureCurrentState(session: session, sessionMinterEnabled: true)

    let callCount = LockIsolated(0)
    let service = MockSessionService(fetchToken: { _, _, _ in
      callCount.withValue { $0 += 1 }
      return mintedToken
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let forcedToken = try await SessionTokenFetcher.shared.getToken(
      session,
      options: .init(skipCache: true)
    )
    let ordinaryToken = try await SessionTokenFetcher.shared.getToken(session)
    let cachedToken = await SessionTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: nil)
    )

    #expect(forcedToken == mintedToken)
    #expect(ordinaryToken == mintedToken)
    #expect(cachedToken == mintedToken)
    #expect(callCount.value == 1)
  }

  @Test
  func hydrationAcceptsStrictlyFresherSessionSnapshot() async throws {
    await SessionTokensCache.shared.clear()

    let session = Session.mock
    let cacheKey = session.tokenCacheKey(template: nil)
    let cachedToken = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 100,
      issuedAt: 100,
      signature: "cached"
    )
    let snapshotToken = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 200,
      issuedAt: 200,
      signature: "snapshot"
    )
    await SessionTokensCache.shared.insertToken(cachedToken, cacheKey: cacheKey)

    await SessionTokensCache.shared.hydrate(snapshotToken, cacheKey: cacheKey)

    let canonicalToken = await SessionTokensCache.shared.getToken(cacheKey: cacheKey)
    #expect(canonicalToken == snapshotToken)
  }

  @Test
  func hydrationPreservesFresherExpiredTokenForNextMint() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    var session = Session.mock
    let snapshotToken = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 100,
      issuedAt: 100,
      expiresAt: 200,
      signature: "snapshot"
    )
    let cachedToken = try token(
      sessionId: session.id,
      organizationId: nil,
      originIssuedAt: 200,
      issuedAt: 200,
      expiresAt: 300,
      signature: "cached"
    )
    session.lastActiveToken = snapshotToken
    configureCurrentState(session: session, sessionMinterEnabled: true)
    await SessionTokensCache.shared.insertToken(
      cachedToken,
      cacheKey: session.tokenCacheKey(template: nil)
    )

    let captured = LockIsolated<SessionTokenRequestParams?>(nil)
    let service = MockSessionService(fetchToken: { _, _, params in
      captured.setValue(params)
      return try token(
        sessionId: session.id,
        organizationId: nil,
        originIssuedAt: 300,
        issuedAt: 300,
        signature: "response"
      )
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    _ = try await SessionTokenFetcher.shared.getToken(session)

    let params = try #require(captured.value)
    #expect(params.token == cachedToken.jwt)
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
    let firstCallGate = SessionTokenFetchGate()
    let firstCallStarted = AsyncStream<Void>.makeStream(
      bufferingPolicy: .bufferingNewest(1)
    )
    defer { firstCallStarted.continuation.finish() }
    let service = MockSessionService(fetchToken: { _, _, _ in
      let callIndex = callCount.withValue { count in
        defer { count += 1 }
        return count
      }
      if callIndex == 0 {
        firstCallStarted.continuation.yield()
        await firstCallGate.suspend()
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
    defer {
      first.cancel()
      Task { await firstCallGate.resume() }
    }
    try await waitForSignal(
      firstCallStarted.stream,
      message: "Timed out waiting for the first forced token refresh to start."
    )
    let second = Task {
      try await SessionTokenFetcher.shared.getToken(
        session,
        options: .init(skipCache: true)
      )
    }
    defer { second.cancel() }

    let secondResult = try await second.value
    await firstCallGate.resume()
    let firstResult = try await first.value
    let cachedToken = await SessionTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: nil)
    )

    #expect(callCount.value == 2)
    #expect(firstResult == staleResponse)
    #expect(secondResult == freshResponse)
    #expect(cachedToken == freshResponse)
  }

  @Test
  func resetCancelsConcurrentForcedRefreshes() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    let session = Session.mock
    configureCurrentState(session: session, sessionMinterEnabled: false)

    let callCount = LockIsolated(0)
    let callsStarted = AsyncStream<Void>.makeStream(
      bufferingPolicy: .bufferingNewest(2)
    )
    let requestGate = SessionTokenFetchGate()
    defer { callsStarted.continuation.finish() }
    let service = MockSessionService(fetchToken: { _, _, _ in
      callCount.withValue { $0 += 1 }
      callsStarted.continuation.yield()
      await requestGate.suspend()
      try Task.checkCancellation()
      return .mock
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
    let second = Task {
      try await SessionTokenFetcher.shared.getToken(
        session,
        options: .init(skipCache: true)
      )
    }
    defer {
      first.cancel()
      second.cancel()
      Task { await requestGate.resume() }
    }

    try await waitForSignal(
      callsStarted.stream,
      message: "Timed out waiting for forced token request A to start."
    )
    try await waitForSignal(
      callsStarted.stream,
      message: "Timed out waiting for forced token request B to start."
    )
    #expect(callCount.value == 2)
    #expect(await SessionTokenFetcher.shared.forcedTokenTasks.count == 2)

    await SessionTokenFetcher.shared.reset()
    await requestGate.resume()

    await #expect(throws: CancellationError.self) {
      try await first.value
    }
    await #expect(throws: CancellationError.self) {
      try await second.value
    }
    #expect(await SessionTokenFetcher.shared.forcedTokenTasks.isEmpty)
  }

  @Test
  func cancellingCallerCancelsForcedRefresh() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    let session = Session.mock
    configureCurrentState(session: session, sessionMinterEnabled: false)

    let callStarted = AsyncStream<Void>.makeStream(
      bufferingPolicy: .bufferingNewest(1)
    )
    let requestGate = SessionTokenFetchGate()
    defer { callStarted.continuation.finish() }
    let service = MockSessionService(fetchToken: { _, _, _ in
      callStarted.continuation.yield()
      await requestGate.suspend()
      try Task.checkCancellation()
      return .mock
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let request = Task {
      try await SessionTokenFetcher.shared.getToken(
        session,
        options: .init(skipCache: true)
      )
    }
    defer {
      request.cancel()
      Task { await requestGate.resume() }
    }
    try await waitForSignal(
      callStarted.stream,
      message: "Timed out waiting for the forced token request to start."
    )

    request.cancel()
    await requestGate.resume()

    await #expect(throws: CancellationError.self) {
      try await request.value
    }
    #expect(await SessionTokenFetcher.shared.forcedTokenTasks.isEmpty)
  }

  @Test
  func completedRequestDoesNotClearReplacementTaskAfterReset() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    let session = Session.mock
    let firstResponse = TokenResource(jwt: "first.jwt.value")
    let secondResponse = TokenResource(jwt: "second.jwt.value")
    configureCurrentState(session: session, sessionMinterEnabled: false)

    let firstCallStarted = AsyncStream<Void>.makeStream(
      bufferingPolicy: .bufferingNewest(1)
    )
    let secondCallStarted = AsyncStream<Void>.makeStream(
      bufferingPolicy: .bufferingNewest(1)
    )
    defer {
      firstCallStarted.continuation.finish()
      secondCallStarted.continuation.finish()
    }

    let firstGate = SessionTokenFetchGate()
    let secondGate = SessionTokenFetchGate()
    let callCount = LockIsolated(0)
    let service = MockSessionService(fetchToken: { _, _, _ in
      let callIndex = callCount.withValue { count in
        defer { count += 1 }
        return count
      }

      switch callIndex {
      case 0:
        firstCallStarted.continuation.yield()
        await firstGate.suspend()
        return firstResponse
      case 1:
        secondCallStarted.continuation.yield()
        await secondGate.suspend()
        return secondResponse
      default:
        return TokenResource(jwt: "unexpected.jwt.value")
      }
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let first = Task {
      try await SessionTokenFetcher.shared.getToken(session)
    }
    defer {
      first.cancel()
      Task { await firstGate.resume() }
    }
    try await waitForSignal(
      firstCallStarted.stream,
      message: "Timed out waiting for token request A to start."
    )

    await SessionTokenFetcher.shared.reset()

    let second = Task {
      try await SessionTokenFetcher.shared.getToken(session)
    }
    defer {
      second.cancel()
      Task { await secondGate.resume() }
    }
    try await waitForSignal(
      secondCallStarted.stream,
      message: "Timed out waiting for replacement token request B to start."
    )

    let cacheKey = session.tokenCacheKey(template: nil)
    let registeredReplacement = await SessionTokenFetcher.shared.tokenTasks[cacheKey]
    let replacementId = try #require(registeredReplacement?.id)

    await firstGate.resume()
    do {
      _ = try await first.value
      Issue.record("Expected reset to cancel token request A.")
    } catch is CancellationError {
      // Expected.
    }

    let remainingTask = await SessionTokenFetcher.shared.tokenTasks[cacheKey]
    #expect(remainingTask?.id == replacementId)

    await secondGate.resume()
    #expect(try await second.value == secondResponse)
    #expect(callCount.value == 2)
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
    expiresAt: Int = 4_000_000_000,
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
      "exp": expiresAt,
    ]
    if let organizationId {
      claims["org_id"] = organizationId
    }
    return try TokenResource(
      jwt: testJWT(header: header, claims: claims, signature: signature)
    )
  }
}

private actor SessionTokenFetchGate {
  private var isOpen = false
  private var continuations: [CheckedContinuation<Void, Never>] = []

  func suspend() async {
    if isOpen {
      return
    }
    await withCheckedContinuation { continuations.append($0) }
  }

  func resume() {
    isOpen = true
    let continuations = continuations
    self.continuations.removeAll()
    continuations.forEach { $0.resume() }
  }
}

private struct SessionTokenSignalTimeoutError: Error, CustomStringConvertible {
  let description: String
}

private func waitForSignal(
  _ stream: AsyncStream<Void>,
  timeout: Duration = .seconds(1),
  message: String
) async throws {
  try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask {
      for await _ in stream {
        return
      }
      throw SessionTokenSignalTimeoutError(description: message)
    }
    group.addTask {
      try await Task.sleep(for: timeout)
      throw SessionTokenSignalTimeoutError(description: message)
    }

    defer { group.cancelAll() }
    _ = try await group.next()
  }
}

@MainActor
private func waitForCondition(
  timeout: Duration = .seconds(1),
  message: String,
  condition: () async -> Bool
) async throws {
  let deadline = ContinuousClock.now + timeout
  while ContinuousClock.now < deadline {
    if await condition() {
      return
    }
    try await Task.sleep(for: .milliseconds(5))
  }

  if await condition() == false {
    throw SessionTokenSignalTimeoutError(description: message)
  }
}
