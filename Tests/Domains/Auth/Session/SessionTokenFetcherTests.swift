@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct SessionTokenFetcherTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
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
  func fetchTokenEmitsTokenRefreshedEvent() async throws {
    let session = Session.mock
    let tokenResource = TokenResource(jwt: "jwt_123")
    let service = MockSessionService(fetchToken: { _, _ in
      tokenResource
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    var events = Clerk.shared.auth.events.makeAsyncIterator()

    _ = try await SessionTokenFetcher.shared.fetchToken(
      session,
      options: .init(skipCache: true)
    )

    let event = try #require(await events.next())
    switch event {
    case .tokenRefreshed(let token):
      #expect(token == tokenResource.jwt)
    default:
      #expect(Bool(false))
    }
  }
}
