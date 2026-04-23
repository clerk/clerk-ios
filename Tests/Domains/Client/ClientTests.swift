@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct ClientTests {
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
    let clerk = Clerk()

    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: service
    )
    clerk.client = nil

    _ = try await clerk.refreshClient()

    #expect(called.value == true)
    #expect(clerk.client?.id == expectedClient.id)
  }

  @Test
  func refreshClientClearsClientWhenServiceReturnsNil() async throws {
    let service = MockClientService(get: { nil })
    let clerk = Clerk()

    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: service
    )
    clerk.client = Client.mock

    let client = try await clerk.refreshClient()

    #expect(client == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func refreshClientIgnoresStaleClientResponseSequence() async throws {
    let current = Client(
      id: "current-client",
      sessions: [],
      lastActiveSessionId: "session-current",
      updatedAt: Date(timeIntervalSince1970: 2000)
    )
    let stale = Client(
      id: "stale-client",
      sessions: [],
      lastActiveSessionId: "session-stale",
      updatedAt: Date(timeIntervalSince1970: 1000)
    )
    let clerk = Clerk()

    clerk.cleanupManagers()

    clerk.applyResponseClient(current, responseSequence: 2)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: SequencedClientService(
        response: ClientServiceResponse(client: stale, requestSequence: 1, serverDate: nil)
      )
    )

    let client = try await clerk.refreshClient()

    #expect(client?.id == current.id)
    #expect(clerk.client?.id == current.id)
    #expect(clerk.client?.lastActiveSessionId == "session-current")
  }

  @Test
  func refreshClientIgnoresStaleNilResponseSequence() async throws {
    let current = Client(
      id: "current-client",
      sessions: [],
      lastActiveSessionId: "session-current",
      updatedAt: Date(timeIntervalSince1970: 2000)
    )
    let clerk = Clerk()

    clerk.cleanupManagers()
    clerk.applyResponseClient(current, responseSequence: 2)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: SequencedClientService(
        response: ClientServiceResponse(client: nil, requestSequence: 1, serverDate: nil)
      )
    )

    let client = try await clerk.refreshClient()

    #expect(client?.id == current.id)
    #expect(clerk.client?.id == current.id)
    #expect(clerk.client?.lastActiveSessionId == "session-current")
  }
}

private final class SequencedClientService: ClientServiceProtocol {
  private let response: ClientServiceResponse

  init(response: ClientServiceResponse) {
    self.response = response
  }

  @MainActor
  func getResponse() async throws -> ClientServiceResponse {
    response
  }
}
