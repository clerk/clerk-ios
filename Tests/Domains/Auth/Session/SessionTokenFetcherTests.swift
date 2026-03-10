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
}
