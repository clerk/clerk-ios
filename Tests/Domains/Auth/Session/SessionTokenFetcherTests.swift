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
    let session = Session.mock
    let captured = LockIsolated<(sessionId: String, template: String?, skipCache: Bool)?>(nil)
    let service = MockSessionService(fetchToken: { sessionId, template, skipCache in
      captured.setValue((sessionId: sessionId, template: template, skipCache: skipCache))
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
    #expect(values.skipCache)
  }

  @Test
  func fetchTokenForwardsSkipCacheFalse() async throws {
    let session = Session.mock
    let captured = LockIsolated<Bool?>(nil)
    let service = MockSessionService(fetchToken: { _, _, skipCache in
      captured.setValue(skipCache)
      return .mock
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    await SessionTokensCache.shared.clear()

    _ = try await SessionTokenFetcher.shared.fetchToken(
      session,
      options: .init(template: UUID().uuidString, skipCache: false)
    )

    #expect(captured.value == false)
  }

  @Test
  func fetchTokenCachesFetchedToken() async throws {
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
  func fetchTokenDropsCacheWriteWhenSessionIsInvalidatedMidFlight() async throws {
    let session = Session.mock
    await SessionTokensCache.shared.clear()

    let service = MockSessionService(fetchToken: { sessionId, _, _ in
      // Stands in for a sign-out or org switch landing while the request is in flight.
      await SessionTokensCache.shared.removeTokens(sessionId: sessionId)
      return .init(jwt: "stale_jwt")
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    _ = try await SessionTokenFetcher.shared.fetchToken(session, options: .init(skipCache: true))

    #expect(await SessionTokensCache.shared.getToken(cacheKey: session.tokenCacheKey(template: nil)) == nil)
  }

  @Test
  func skipCacheRequestDoesNotJoinAnInFlightNormalRequest() async throws {
    let session = Session.mock
    await SessionTokensCache.shared.clear()

    let observedSkipCache = LockIsolated<[Bool]>([])
    let release = LockIsolated(false)
    let service = MockSessionService(fetchToken: { _, _, skipCache in
      observedSkipCache.withValue { $0.append(skipCache) }
      while !release.value {
        try? await Task.sleep(for: .milliseconds(5))
      }
      return .mock
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let normalRequest = Task { @MainActor in
      try await SessionTokenFetcher.shared.getToken(session, options: .init(skipCache: false))
    }
    try await waitUntil { observedSkipCache.value.count == 1 }

    let forcedRequest = Task { @MainActor in
      try await SessionTokenFetcher.shared.getToken(session, options: .init(skipCache: true))
    }

    do {
      try await waitUntil { observedSkipCache.value.count == 2 }
    } catch {
      release.setValue(true)
      _ = try? await normalRequest.value
      _ = try? await forcedRequest.value
      Issue.record("skipCache request joined the in-flight request instead of forcing origin")
      return
    }

    release.setValue(true)
    _ = try await normalRequest.value
    _ = try await forcedRequest.value

    #expect(observedSkipCache.value.contains(false))
    #expect(observedSkipCache.value.contains(true))
  }

  @Test
  func normalRequestForDelimiterTemplateDoesNotJoinAForcedRequestForAnotherTemplate() async throws {
    let session = Session.mock
    await SessionTokensCache.shared.clear()

    // A forced request for template "foo" and a normal request for a template literally
    // named "foo|force" would collide if the dedupe key concatenated a "|force" delimiter.
    let observed = LockIsolated<[(template: String?, skipCache: Bool)]>([])
    let release = LockIsolated(false)
    let service = MockSessionService(fetchToken: { _, template, skipCache in
      observed.withValue { $0.append((template: template, skipCache: skipCache)) }
      while !release.value {
        try? await Task.sleep(for: .milliseconds(5))
      }
      return .mock
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    let forcedRequest = Task { @MainActor in
      try await SessionTokenFetcher.shared.getToken(session, options: .init(template: "foo", skipCache: true))
    }
    try await waitUntil { observed.value.count == 1 }

    let normalRequest = Task { @MainActor in
      try await SessionTokenFetcher.shared.getToken(session, options: .init(template: "foo|force", skipCache: false))
    }

    do {
      try await waitUntil { observed.value.count == 2 }
    } catch {
      release.setValue(true)
      _ = try? await forcedRequest.value
      _ = try? await normalRequest.value
      Issue.record("Requests with colliding delimiter keys joined the same task")
      return
    }

    release.setValue(true)
    _ = try await forcedRequest.value
    _ = try await normalRequest.value

    #expect(observed.value.contains { $0.template == "foo" && $0.skipCache })
    #expect(observed.value.contains { $0.template == "foo|force" && !$0.skipCache })
  }

  private func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: () -> Bool
  ) async throws {
    enum TimeoutError: Error {
      case timedOut
    }

    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if condition() {
        return
      }
      try await Task.sleep(for: .milliseconds(10))
    }

    if !condition() {
      throw TimeoutError.timedOut
    }
  }
}

struct SessionTokensCacheTests {
  private func jwt(oiat: Int?, iat: Int?) -> TokenResource {
    var header: [String: Any] = ["alg": "RS256", "typ": "JWT"]
    if let oiat {
      header["oiat"] = oiat
    }
    var payload: [String: Any] = ["sid": "sess_1"]
    if let iat {
      payload["iat"] = iat
    }

    return .init(jwt: [base64URLEncodedJSON(header), base64URLEncodedJSON(payload), "signature"].joined(separator: "."))
  }

  private func base64URLEncodedJSON(_ object: [String: Any]) -> String {
    let data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    return data
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  @Test
  func insertTokenKeepsExistingTokenWhenIncomingOiatIsOlder() async {
    let cache = SessionTokensCache()
    let existing = jwt(oiat: 2000, iat: 2000)
    let incoming = jwt(oiat: 1000, iat: 3000)

    await cache.insertToken(existing, cacheKey: "sess_1")
    await cache.insertToken(incoming, cacheKey: "sess_1")

    #expect(await cache.getToken(cacheKey: "sess_1") == existing)
  }

  @Test
  func insertTokenReplacesExistingTokenWhenIncomingOiatIsNewer() async {
    let cache = SessionTokensCache()
    let existing = jwt(oiat: 1000, iat: 1000)
    let incoming = jwt(oiat: 2000, iat: 2000)

    await cache.insertToken(existing, cacheKey: "sess_1")
    await cache.insertToken(incoming, cacheKey: "sess_1")

    #expect(await cache.getToken(cacheKey: "sess_1") == incoming)
  }

  @Test
  func insertTokenBreaksEqualOiatTiesWithIssuedAt() async {
    let cache = SessionTokensCache()
    let existing = jwt(oiat: 1000, iat: 2000)
    let stale = jwt(oiat: 1000, iat: 1000)
    let fresh = jwt(oiat: 1000, iat: 3000)

    await cache.insertToken(existing, cacheKey: "sess_1")
    await cache.insertToken(stale, cacheKey: "sess_1")
    #expect(await cache.getToken(cacheKey: "sess_1") == existing)

    await cache.insertToken(fresh, cacheKey: "sess_1")
    #expect(await cache.getToken(cacheKey: "sess_1") == fresh)
  }

  @Test
  func insertTokenKeepsExistingTokenWhenIncomingHasNoOiat() async {
    let cache = SessionTokensCache()
    let existing = jwt(oiat: 1000, iat: 1000)
    let incoming = jwt(oiat: nil, iat: 3000)

    await cache.insertToken(existing, cacheKey: "sess_1")
    await cache.insertToken(incoming, cacheKey: "sess_1")

    #expect(await cache.getToken(cacheKey: "sess_1") == existing)
  }

  @Test
  func insertTokenOverwritesWhenNeitherTokenHasOiat() async {
    let cache = SessionTokensCache()
    let existing = TokenResource(jwt: "jwt_123")
    let incoming = TokenResource(jwt: "jwt_456")

    await cache.insertToken(existing, cacheKey: "sess_1")
    await cache.insertToken(incoming, cacheKey: "sess_1")

    #expect(await cache.getToken(cacheKey: "sess_1") == incoming)
  }

  @Test
  func insertTokenDropsWritesFromBeforeRemoveTokens() async {
    let cache = SessionTokensCache()
    let generation = await cache.generation(sessionId: "sess_1")

    await cache.removeTokens(sessionId: "sess_1")
    await cache.insertToken(.init(jwt: "stale"), cacheKey: "sess_1", generation: generation)

    #expect(await cache.getToken(cacheKey: "sess_1") == nil)
  }

  @Test
  func insertTokenDropsWritesFromBeforeClear() async {
    let cache = SessionTokensCache()
    let generation = await cache.generation(sessionId: "sess_1")

    await cache.clear()
    await cache.insertToken(.init(jwt: "stale"), cacheKey: "sess_1", generation: generation)

    #expect(await cache.getToken(cacheKey: "sess_1") == nil)
  }

  @Test
  func insertTokenKeepsWritesFromTheCurrentGeneration() async {
    let cache = SessionTokensCache()
    await cache.removeTokens(sessionId: "sess_1")
    let generation = await cache.generation(sessionId: "sess_1")

    await cache.insertToken(.init(jwt: "fresh"), cacheKey: "sess_1", generation: generation)

    #expect(await cache.getToken(cacheKey: "sess_1")?.jwt == "fresh")
  }

  @Test
  func insertTokenIsNotFencedByAnotherSessionsInvalidation() async {
    let cache = SessionTokensCache()
    let generation = await cache.generation(sessionId: "sess_1")

    await cache.removeTokens(sessionId: "sess_2")
    await cache.insertToken(.init(jwt: "fresh"), cacheKey: "sess_1", generation: generation)

    #expect(await cache.getToken(cacheKey: "sess_1")?.jwt == "fresh")
  }

  @Test
  func removeTokensClearsEveryTokenForTheSession() async {
    let cache = SessionTokensCache()
    await cache.insertToken(.init(jwt: "default"), cacheKey: "sess_1")
    await cache.insertToken(.init(jwt: "template"), cacheKey: "sess_1-firebase")
    await cache.insertToken(.init(jwt: "other"), cacheKey: "sess_12")

    await cache.removeTokens(sessionId: "sess_1")

    #expect(await cache.getToken(cacheKey: "sess_1") == nil)
    #expect(await cache.getToken(cacheKey: "sess_1-firebase") == nil)
    #expect(await cache.getToken(cacheKey: "sess_12")?.jwt == "other")
  }
}
