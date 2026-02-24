@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClientTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  @Test
  func refreshClientUsesClientServiceGet() async throws {
    let called = LockIsolated(false)
    let expectedClient = Client(
      id: "refresh-client-test",
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let service = MockClientService(get: {
      called.setValue(true)
      return expectedClient
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: service
    )

    _ = try await Clerk.shared.refreshClient()

    #expect(called.value == true)
    #expect(Clerk.shared.client?.id == expectedClient.id)
  }

  @Test
  func prepareAuthenticatedWebURLUsesClientService() async throws {
    let called = LockIsolated(false)
    let expectedURL = try #require(URL(string: "https://example.com/v1/client/initialize_webview?token=abc"))
    let service = MockClientService(
      get: {
        .mock
      },
      prepareAuthenticatedWebURL: { redirectURL in
        called.setValue(true)
        #expect(redirectURL.absoluteString == "https://example.com/checkout")
        return expectedURL
      }
    )

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: service
    )

    let url = try await Clerk.shared.prepareAuthenticatedWebURL(for: #require(URL(string: "https://example.com/checkout")))

    #expect(called.value == true)
    #expect(url == expectedURL)
  }
}
