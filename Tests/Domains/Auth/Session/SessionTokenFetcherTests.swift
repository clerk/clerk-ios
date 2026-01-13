import ConcurrencyExtras
import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct SessionTokenFetcherTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  @Test
  func fetchTokenUsesSessionService() async throws {
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

    _ = try await SessionTokenFetcher.shared.fetchToken(session, options: .init(skipCache: true))

    let values = try #require(captured.value)
    #expect(values.sessionId == session.id)
    #expect(values.template == nil)
  }

  @Test
  func fetchTokenWithTemplateUsesSessionService() async throws {
    let session = Session.mock
    let template = "firebase"
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
      options: .init(template: template, skipCache: true)
    )

    let values = try #require(captured.value)
    #expect(values.sessionId == session.id)
    #expect(values.template == template)
  }
}
