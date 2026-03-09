@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClientTests {
  @Test
  func refreshClientUsesClientServiceGet() async throws {
    configureClerkForTesting()
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
    Clerk.shared.client = nil

    _ = try await Clerk.shared.refreshClient()

    #expect(called.value == true)
    #expect(Clerk.shared.client?.id == expectedClient.id)
  }

  @Test
  func refreshClientDoesNotClearClientWhenServiceReturnsNil() async throws {
    configureClerkForTesting()
    let service = MockClientService(get: { nil })
    let existingClient = Client.mock

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: service
    )
    Clerk.shared.client = existingClient

    let client = try await Clerk.shared.refreshClient()

    #expect(client == nil)
    #expect(Clerk.shared.client?.id == existingClient.id)
  }
}
