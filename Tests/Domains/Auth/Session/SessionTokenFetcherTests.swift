@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct SessionTokenFetcherTests {
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
    let cache = SessionTokensCache()
    let fetcher = SessionTokenFetcher(
      sessionService: service,
      tokenCache: cache
    )

    _ = try await fetcher.fetchToken(session, options: .init(template: scenario.template, skipCache: true))

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
    let cache = SessionTokensCache()
    let fetcher = SessionTokenFetcher(
      sessionService: service,
      tokenCache: cache
    )

    _ = try await fetcher.fetchToken(session, options: .init(template: template, skipCache: true))

    let cachedToken = await cache.getToken(
      cacheKey: session.tokenCacheKey(template: template)
    )
    #expect(cachedToken == tokenResource)
  }
}
