@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClientTests {
  private struct LegacyNilClientService: ClientServiceProtocol {
    @MainActor
    func get() async throws -> Client? {
      nil
    }
  }

  init() {
    configureClerkForTesting()
  }

  @Test
  func refreshClientUsesClientServiceGet() async throws {
    Clerk.shared.resetClientResponseSequenceTracking()
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
    Clerk.shared.resetClientResponseSequenceTracking()
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

  @Test
  func refreshClientNilResponseClearsState() async throws {
    Clerk.shared.resetClientResponseSequenceTracking()
    Clerk.shared.client = .mock

    let service = MockClientService()
    service.getResponseHandler = {
      ClientServiceResponse(
        client: nil,
        requestSequence: 10
      )
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: service
    )

    let refreshedClient = try await Clerk.shared.refreshClient()

    #expect(refreshedClient == nil)
    #expect(Clerk.shared.client == nil)
  }

  @Test
  func refreshClientIgnoresStaleNilResponse() async throws {
    Clerk.shared.resetClientResponseSequenceTracking()
    Clerk.shared.client = nil

    let service = MockClientService()
    var calls = 0
    service.getResponseHandler = {
      calls += 1
      if calls == 1 {
        var client = Client.mock
        client.id = "fresh-client"
        client.updatedAt = Date(timeIntervalSince1970: 300)
        return ClientServiceResponse(
          client: client,
          requestSequence: 2
        )
      }

      return ClientServiceResponse(
        client: nil,
        requestSequence: 1
      )
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: service
    )

    _ = try await Clerk.shared.refreshClient()
    let refreshedClient = try await Clerk.shared.refreshClient()

    let currentClient = try #require(Clerk.shared.client)
    #expect(currentClient.id == "fresh-client")
    #expect(refreshedClient?.id == "fresh-client")
  }

  @Test
  func refreshClientWithLegacyGetOnlyServiceCanClearClient() async throws {
    Clerk.shared.resetClientResponseSequenceTracking()
    Clerk.shared.client = .mock

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: LegacyNilClientService()
    )

    let refreshedClient = try await Clerk.shared.refreshClient()

    #expect(refreshedClient == nil)
    #expect(Clerk.shared.client == nil)
  }
}
