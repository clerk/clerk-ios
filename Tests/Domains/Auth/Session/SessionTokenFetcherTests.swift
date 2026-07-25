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
    let captured = LockIsolated<(sessionId: String, template: String?)?>(nil)
    let service = MockSessionService(fetchToken: { sessionId, template in
      captured.setValue((sessionId: sessionId, template: template))
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
  }

  @Test
  func fetchTokenCachesFetchedToken() async throws {
    let session = Session.mock
    let template = UUID().uuidString
    let tokenResource = TokenResource(jwt: "jwt_123")
    let service = MockSessionService(fetchToken: { _, _ in
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
  func keychainClearInvalidatesCachedTokenForRetainedSession() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    let retainedSession = Session.mock
    let cachedToken = try makeUnexpiredToken()
    let fetchCount = LockIsolated(0)
    let sessionService = MockSessionService(fetchToken: { _, _ in
      fetchCount.withValue { $0 += 1 }
      return nil
    })
    try installClearDependencies(sessionService: sessionService)

    await SessionTokensCache.shared.insertToken(
      cachedToken,
      cacheKey: retainedSession.tokenCacheKey(template: nil)
    )
    #expect(try await retainedSession.getToken() == cachedToken.jwt)
    #expect(fetchCount.value == 0)

    try await Clerk.clearAllKeychainItemsAndWait()

    #expect(try await retainedSession.getToken() == nil)
    #expect(fetchCount.value == 1)
    #expect(
      await SessionTokensCache.shared.getToken(
        cacheKey: retainedSession.tokenCacheKey(template: nil)
      ) == nil
    )
  }

  @Test
  func keychainClearCancelsInFlightTokenFetch() async throws {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    let retainedSession = Session.mock
    let fetchGate = SuspendedTokenFetch()
    let token = try makeUnexpiredToken()
    let sessionService = MockSessionService(fetchToken: { _, _ in
      await fetchGate.fetch()
    })
    try installClearDependencies(sessionService: sessionService)

    let fetchTask = Task {
      try await retainedSession.getToken(.init(skipCache: true))
    }
    await fetchGate.waitUntilStarted()

    try await Clerk.clearAllKeychainItemsAndWait()
    await fetchGate.release(returning: token)

    await #expect(throws: CancellationError.self) {
      try await fetchTask.value
    }
    #expect(
      await SessionTokensCache.shared.getToken(
        cacheKey: retainedSession.tokenCacheKey(template: nil)
      ) == nil
    )
  }

  private func installClearDependencies(
    sessionService: MockSessionService
  ) throws {
    let clerk = Clerk.shared
    let keychain = InMemoryKeychain()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      sessionService: sessionService
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init()
    )
    try clerk.performConfiguration(dependencies: dependencies)
    clerk.cleanupManagers()
  }

  private func makeUnexpiredToken() throws -> TokenResource {
    func base64URL(_ data: Data) -> String {
      data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    }

    let header = try JSONSerialization.data(
      withJSONObject: ["alg": "none", "typ": "JWT"]
    )
    let payload = try JSONSerialization.data(
      withJSONObject: [
        "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
      ]
    )
    return TokenResource(
      jwt: "\(base64URL(header)).\(base64URL(payload)).signature"
    )
  }
}

private actor SuspendedTokenFetch {
  private var started = false
  private var startedWaiters: [CheckedContinuation<Void, Never>] = []
  private var fetchContinuation:
    CheckedContinuation<TokenResource?, Never>?

  func fetch() async -> TokenResource? {
    await withCheckedContinuation { continuation in
      fetchContinuation = continuation
      started = true
      let waiters = startedWaiters
      startedWaiters.removeAll()
      for waiter in waiters {
        waiter.resume()
      }
    }
  }

  func waitUntilStarted() async {
    guard !started else { return }
    await withCheckedContinuation { continuation in
      startedWaiters.append(continuation)
    }
  }

  func release(returning token: TokenResource?) {
    fetchContinuation?.resume(returning: token)
    fetchContinuation = nil
  }
}
