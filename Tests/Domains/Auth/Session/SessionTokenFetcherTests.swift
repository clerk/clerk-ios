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

    let events = Clerk.shared.auth.events

    _ = try await SessionTokenFetcher.shared.fetchToken(
      session,
      options: .init(skipCache: true)
    )

    let token = try await nextRefreshedToken(from: events)
    #expect(token == tokenResource.jwt)
  }

  private func nextRefreshedToken(
    from events: AsyncStream<AuthEvent>,
    timeout: Duration = .seconds(1)
  ) async throws -> String {
    enum WaitError: Error {
      case timeout
    }

    return try await withThrowingTaskGroup(of: String.self) { group in
      group.addTask {
        var iterator = events.makeAsyncIterator()
        while let event = await iterator.next() {
          if case .tokenRefreshed(let token) = event {
            return token
          }
        }

        throw WaitError.timeout
      }

      group.addTask {
        try await Task.sleep(for: timeout)
        throw WaitError.timeout
      }

      let token = try await group.next()
      group.cancelAll()
      return try #require(token, "Expected tokenRefreshed event")
    }
  }
}
