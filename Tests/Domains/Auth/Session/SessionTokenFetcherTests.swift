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
    try await withMainSerialExecutor {
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
  }

  @Test
  func fetchTokenEmitsTokenRefreshedEvent() async throws {
    try await withMainSerialExecutor {
      let session = Session.mock
      let tokenResource = TokenResource(jwt: "jwt_123")
      let service = MockSessionService(fetchToken: { _, _ in
        tokenResource
      })

      Clerk.shared.dependencies = MockDependencyContainer(
        apiClient: createMockAPIClient(),
        sessionService: service
      )

      let eventStream = Clerk.shared.auth.events
      let tokenEventTask = Task<AuthEvent?, Never> {
        var events = eventStream.makeAsyncIterator()
        return await events.next()
      }

      _ = try await SessionTokenFetcher.shared.fetchToken(
        session,
        options: .init(skipCache: true)
      )

      let event = await waitForAuthEvent(tokenEventTask)
      tokenEventTask.cancel()

      let emittedEvent = try #require(event)
      switch emittedEvent {
      case .tokenRefreshed(let token):
        #expect(token == tokenResource.jwt)
      default:
        Issue.record("Expected .tokenRefreshed event after fetching a new token.")
      }
    }
  }

  private func waitForAuthEvent(_ eventTask: Task<AuthEvent?, Never>) async -> AuthEvent? {
    await withTaskGroup(of: AuthEvent?.self) { group in
      group.addTask {
        await eventTask.value
      }
      group.addTask {
        try? await Task.sleep(for: .seconds(1))
        return nil
      }
      defer { group.cancelAll() }
      return await group.next() ?? nil
    }
  }
}
