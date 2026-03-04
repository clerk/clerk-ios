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

      var events = Clerk.shared.auth.events.makeAsyncIterator()
      let tokenEventTask = Task<String?, Never> { @MainActor in
        while let event = await events.next() {
          if case .tokenRefreshed(let token) = event, token == tokenResource.jwt {
            return token
          }
        }
        return nil
      }

      _ = try await SessionTokenFetcher.shared.fetchToken(
        session,
        options: .init(skipCache: true)
      )

      let refreshedToken = await waitForRefreshedToken(tokenEventTask)
      tokenEventTask.cancel()
      #expect(refreshedToken == tokenResource.jwt)
    }
  }

  private func waitForRefreshedToken(_ eventTask: Task<String?, Never>) async -> String? {
    await withTaskGroup(of: String?.self) { group in
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
