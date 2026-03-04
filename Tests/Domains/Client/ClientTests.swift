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
    Clerk.shared.client = nil

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

    let refreshedClient = try await Clerk.shared.refreshClient()

    #expect(called.value == true)
    #expect(Clerk.shared.client?.id == expectedClient.id)
    #expect(refreshedClient?.id == expectedClient.id)
  }

  @Test
  func refreshClientDoesNotOverrideNewerClientSnapshot() async throws {
    var currentClient = Client.mock
    currentClient.id = "current-client"
    currentClient.updatedAt = Date(timeIntervalSince1970: 300)
    Clerk.shared.client = currentClient

    var staleClient = Client.mock
    staleClient.id = "stale-client"
    staleClient.updatedAt = Date(timeIntervalSince1970: 200)

    let service = MockClientService(get: {
      staleClient
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: service
    )

    let refreshedClient = try await Clerk.shared.refreshClient()

    #expect(Clerk.shared.client?.id == currentClient.id)
    #expect(Clerk.shared.client?.updatedAt == currentClient.updatedAt)
    #expect(refreshedClient?.id == currentClient.id)
    #expect(refreshedClient?.updatedAt == currentClient.updatedAt)
  }
}
