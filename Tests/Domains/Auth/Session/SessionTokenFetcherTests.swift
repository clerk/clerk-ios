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

private actor SessionTokenFetchGate {
  private var isOpen = false
  private var continuation: CheckedContinuation<Void, Never>?

  func suspend() async {
    if isOpen {
      return
    }
    await withCheckedContinuation { continuation = $0 }
  }

  func resume() {
    if let continuation {
      continuation.resume()
      self.continuation = nil
    } else {
      isOpen = true
    }
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
