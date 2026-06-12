@_spi(FrameworkIntegration) @testable import ClerkKit
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
        response: ClientServiceResponse(client: stale, requestSequence: 1, serverDate: nil)
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
        response: ClientServiceResponse(client: nil, requestSequence: 1, serverDate: nil)
      )
    )

    let client = try await Clerk.shared.refreshClient()

    #expect(client?.id == current.id)
    #expect(Clerk.shared.client?.id == current.id)
    #expect(Clerk.shared.client?.lastActiveSessionId == "session-current")
  }

  @Test
  func updateDeviceTokenStoresTokenAndRefreshesWithoutClientId() async throws {
    configureClerkForTesting()
    Clerk.shared.cleanupManagers()

    let keychain = InMemoryKeychain()
    try keychain.set("old-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set(#require("cached-client".data(using: .utf8)), forKey: ClerkKeychainKey.cachedClient.rawValue)
    try keychain.set("cached-date", forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
    try keychain.set(#require("cached-environment".data(using: .utf8)), forKey: ClerkKeychainKey.cachedEnvironment.rawValue)

    let expectedClient = Client(
      id: "updated-token-client",
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let service = DeviceTokenUpdateClientService(
      response: ClientServiceResponse(client: expectedClient, requestSequence: 1, serverDate: Date(timeIntervalSince1970: 2000))
    )

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      clientService: service
    )
    Clerk.shared.client = Client.mock

    let client = try await Clerk.shared.updateDeviceToken("new-token")

    #expect(client?.id == expectedClient.id)
    #expect(Clerk.shared.client?.id == expectedClient.id)
    #expect(Clerk.shared.deviceToken == "new-token")
    #expect(service.skipClientIdValues == [true])
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) == false)
  }

  @Test
  func refreshClientIgnoresResponseWhenDeviceTokenGenerationChangesDuringRequest() async throws {
    configureClerkForTesting()
    Clerk.shared.cleanupManagers()

    let staleClient = Client(
      id: "stale-client",
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let service = DeviceTokenChangingClientService(
      response: ClientServiceResponse(client: staleClient, requestSequence: 1, serverDate: Date(timeIntervalSince1970: 2000))
    )

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: service
    )

    let client = try await Clerk.shared.refreshClient()

    #expect(client == nil)
    #expect(Clerk.shared.client == nil)
  }

  @Test
  func updateDeviceTokenRejectsBlankToken() async throws {
    configureClerkForTesting()

    await #expect(throws: Clerk.DeviceTokenError.emptyToken) {
      try await Clerk.shared.updateDeviceToken("   ")
    }
  }
}

private final class SequencedClientService: ClientServiceProtocol {
  private let response: ClientServiceResponse

  init(response: ClientServiceResponse) {
    self.response = response
  }

  @MainActor
  func getResponse(skipClientId _: Bool = false) async throws -> ClientServiceResponse {
    response
  }
}

private final class DeviceTokenUpdateClientService: ClientServiceProtocol {
  private let response: ClientServiceResponse
  private let skipClientIdValuesStore = LockIsolated([Bool]())

  var skipClientIdValues: [Bool] {
    skipClientIdValuesStore.value
  }

  init(response: ClientServiceResponse) {
    self.response = response
  }

  @MainActor
  func getResponse(skipClientId: Bool) async throws -> ClientServiceResponse {
    skipClientIdValuesStore.withValue { $0.append(skipClientId) }
    return response
  }
}

private final class DeviceTokenChangingClientService: ClientServiceProtocol {
  private let response: ClientServiceResponse

  init(response: ClientServiceResponse) {
    self.response = response
  }

  @MainActor
  func getResponse(skipClientId _: Bool) async throws -> ClientServiceResponse {
    Clerk.shared.clearCachedClientStateAfterDeviceTokenChange()
    return response
  }
}
