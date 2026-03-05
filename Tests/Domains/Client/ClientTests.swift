@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClientTests {
  private struct ResponseOnlyClientService: ClientServiceProtocol {
    let client: Client?
    let requestSequence: UInt64?

    @MainActor
    func getResponse() async throws -> ClientServiceResponse {
      ClientServiceResponse(
        client: client,
        requestSequence: requestSequence
      )
    }
  }

  private struct ResponseOnlyNilClientService: ClientServiceProtocol {
    let requestSequence: UInt64?

    @MainActor
    func getResponse() async throws -> ClientServiceResponse {
      ClientServiceResponse(
        client: nil,
        requestSequence: requestSequence
      )
    }
  }

  init() {
    configureClerkForTesting()
  }

  private func setUpClerkClient(_ client: Client?) {
    Clerk.shared.resetClientResponseSequenceTracking()
    Clerk.shared.client = client
  }

  @Test
  func refreshClientUsesClientServiceGet() async throws {
    setUpClerkClient(nil)

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
  func refreshClientAppliesUnsequencedClientWhenStateIsEmpty() async throws {
    setUpClerkClient(nil)

    var expectedClient = Client.mock
    expectedClient.id = "unsequenced-initial-client"
    expectedClient.updatedAt = Date(timeIntervalSince1970: 1_800_000_000)

    let service = MockClientService()
    service.getResponseHandler = {
      ClientServiceResponse(
        client: expectedClient,
        requestSequence: nil
      )
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: service
    )

    let refreshedClient = try await Clerk.shared.refreshClient()

    #expect(refreshedClient?.id == expectedClient.id)
    #expect(Clerk.shared.client?.id == expectedClient.id)
  }

  @Test
  func refreshClientDoesNotOverrideNewerClientSnapshot() async throws {
    var currentClient = Client.mock
    currentClient.id = "current-client"
    currentClient.updatedAt = Date(timeIntervalSince1970: 300)
    setUpClerkClient(currentClient)

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
    setUpClerkClient(.mock)

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
  func refreshClientNilUnsequencedResponseClearsState() async throws {
    setUpClerkClient(.mock)

    let service = MockClientService()
    service.getResponseHandler = {
      ClientServiceResponse(
        client: nil,
        requestSequence: nil
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
    setUpClerkClient(nil)

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
  func mergeClientFromResponseRequiresSequenceWhenCurrentClientIsNil() async {
    setUpClerkClient(.mock)

    await Clerk.shared.applyAuthoritativeClear(
      responseSequence: 5,
      flush: false,
      requiresOrderingProof: true
    )

    #expect(Clerk.shared.client == nil)

    var unsequencedClient = Client.mock
    unsequencedClient.id = "unsequenced-late-client"
    unsequencedClient.updatedAt = Date(timeIntervalSince1970: 400)
    Clerk.shared.mergeClientFromResponse(unsequencedClient, responseSequence: nil)

    #expect(Clerk.shared.client == nil)

    var equalSequenceClient = Client.mock
    equalSequenceClient.id = "equal-sequence-client"
    equalSequenceClient.updatedAt = Date(timeIntervalSince1970: 450)
    Clerk.shared.mergeClientFromResponse(equalSequenceClient, responseSequence: 5)

    #expect(Clerk.shared.client?.id == equalSequenceClient.id)

    var sequencedClient = Client.mock
    sequencedClient.id = "sequenced-client"
    sequencedClient.updatedAt = Date(timeIntervalSince1970: 500)
    Clerk.shared.mergeClientFromResponse(sequencedClient, responseSequence: 6)

    #expect(Clerk.shared.client?.id == sequencedClient.id)
  }

  @Test
  func mergeClientFromResponseRejectsEqualSequenceWhenCurrentClientExists() async {
    Clerk.shared.resetClientResponseSequenceTracking()
    let currentSequence: UInt64 = 5

    await Clerk.shared.applyAuthoritativeClear(
      responseSequence: currentSequence,
      flush: false,
      requiresOrderingProof: true
    )

    var existingClient = Client.mock
    existingClient.id = "existing-client"
    existingClient.updatedAt = Date(timeIntervalSince1970: 500)
    Clerk.shared.client = existingClient

    var equalSequenceClient = Client.mock
    equalSequenceClient.id = "equal-sequence-incoming-client"
    equalSequenceClient.updatedAt = Date(timeIntervalSince1970: 600)
    Clerk.shared.mergeClientFromResponse(equalSequenceClient, responseSequence: currentSequence)

    #expect(Clerk.shared.client?.id == existingClient.id)
    #expect(Clerk.shared.client?.updatedAt == existingClient.updatedAt)

    var newerSequenceClient = Client.mock
    newerSequenceClient.id = "newer-sequence-client"
    newerSequenceClient.updatedAt = Date(timeIntervalSince1970: 700)
    Clerk.shared.mergeClientFromResponse(newerSequenceClient, responseSequence: currentSequence + 1)

    #expect(Clerk.shared.client?.id == newerSequenceClient.id)
  }

  @Test
  func staleHigherSequenceSnapshotStillAdvancesOrderingAndBlocksLowerClear() async throws {
    var currentClient = Client.mock
    currentClient.id = "current-client"
    currentClient.updatedAt = Date(timeIntervalSince1970: 500)
    setUpClerkClient(currentClient)

    var staleHigherSequenceClient = Client.mock
    staleHigherSequenceClient.id = "stale-higher-sequence-client"
    staleHigherSequenceClient.updatedAt = Date(timeIntervalSince1970: 400)
    Clerk.shared.mergeClientFromResponse(staleHigherSequenceClient, responseSequence: 11)

    await Clerk.shared.applyAuthoritativeClear(
      responseSequence: 10,
      flush: false,
      requiresOrderingProof: true
    )

    let resultingClient = try #require(Clerk.shared.client)
    #expect(resultingClient.id == currentClient.id)
    #expect(resultingClient.updatedAt == currentClient.updatedAt)
  }

  @Test
  func refreshClientWithResponseOnlyServiceCanClearClient() async throws {
    setUpClerkClient(.mock)

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: ResponseOnlyNilClientService(requestSequence: 1)
    )

    let refreshedClient = try await Clerk.shared.refreshClient()

    #expect(refreshedClient == nil)
    #expect(Clerk.shared.client == nil)
  }

  @Test
  func refreshClientWithResponseOnlyServiceCanApplyClient() async throws {
    setUpClerkClient(nil)

    var legacyClient = Client.mock
    legacyClient.id = "legacy-get-client"
    legacyClient.updatedAt = Date(timeIntervalSince1970: 1_900_000_000)

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: ResponseOnlyClientService(
        client: legacyClient,
        requestSequence: 1
      )
    )

    let refreshedClient = try await Clerk.shared.refreshClient()

    #expect(refreshedClient?.id == legacyClient.id)
    #expect(Clerk.shared.client?.id == legacyClient.id)
  }
}
