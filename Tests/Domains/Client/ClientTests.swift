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
  func refreshClientClearsClientWhenServiceReturnsNil() async throws {
    configureClerkForTesting()
    let service = MockClientService(get: { nil })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: service
    )
    Clerk.shared.client = Client.mock

    let client = try await Clerk.shared.refreshClient()

    #expect(client == nil)
    #expect(Clerk.shared.client == nil)
  }

  @Test
  func refreshClientIgnoresStaleClientResponseSequence() async throws {
    configureClerkForTesting()
    Clerk.shared.cleanupManagers()

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

    Clerk.shared.applyResponseClient(current, responseSequence: 2)
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: SequencedClientService(
        response: ClientServiceResponse(client: stale, requestSequence: 1)
      )
    )

    let client = try await Clerk.shared.refreshClient()

    #expect(client?.id == current.id)
    #expect(Clerk.shared.client?.id == current.id)
    #expect(Clerk.shared.client?.lastActiveSessionId == "session-current")
  }

  @Test
  func refreshClientIgnoresStaleNilResponseSequence() async throws {
    configureClerkForTesting()
    Clerk.shared.cleanupManagers()

    let current = Client(
      id: "current-client",
      sessions: [],
      lastActiveSessionId: "session-current",
      updatedAt: Date(timeIntervalSince1970: 2000)
    )

    Clerk.shared.applyResponseClient(current, responseSequence: 2)
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: SequencedClientService(
        response: ClientServiceResponse(client: nil, requestSequence: 1)
      )
    )

    let client = try await Clerk.shared.refreshClient()

    #expect(client?.id == current.id)
    #expect(Clerk.shared.client?.id == current.id)
    #expect(Clerk.shared.client?.lastActiveSessionId == "session-current")
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
