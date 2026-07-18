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
  func refreshClientPreservesClientWhenCanonicalResponseHasNoClient() async throws {
    configureClerkForTesting()
    let service = MockClientService(get: { nil })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: service
    )
    Clerk.shared.client = Client.mock

    let client = try await Clerk.shared.refreshClient()

    #expect(client?.id == Client.mock.id)
    #expect(Clerk.shared.client?.id == Client.mock.id)
  }

  @Test
  func refreshClientPreservesAdoptedAtomicIdentityWhenCanonicalResponseHasNoClient() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let previous = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "current-token",
      client: Client.mock,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try identityStore.save(previous)
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      sharedSessionLocalIdentityStore: identityStore,
      clientService: MockClientService(get: { nil })
    )
    Clerk.shared.client = nil
    Clerk.shared.setSharedSessionIdentityIfNeeded(previous)

    let client = try await Clerk.shared.refreshClient()

    let stored = try #require(try identityStore.load())
    #expect(client?.id == Client.mock.id)
    #expect(Clerk.shared.client?.id == Client.mock.id)
    #expect(stored.state == previous.state)
    #expect(stored.deviceToken == previous.deviceToken)
    #expect(stored.client?.id == previous.client?.id)
    #expect(stored.serverDate == previous.serverDate)
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

    let client = try await Clerk.shared.updateDeviceToken(" new-token\n")

    #expect(client?.id == expectedClient.id)
    #expect(Clerk.shared.client?.id == expectedClient.id)
    #expect(Clerk.shared.deviceToken == "new-token")
    #expect(service.skipClientIdValues == [true])
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedEnvironment.rawValue))
  }

  @Test
  func updateDeviceTokenContinuesWhenInternalStateObserverThrows() async throws {
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
    Clerk.shared.internalStateChanges.addObserver(ThrowingInternalStateChangeObserver())

    let client = try await Clerk.shared.updateDeviceToken(" new-token\n")

    #expect(client?.id == expectedClient.id)
    #expect(Clerk.shared.client?.id == expectedClient.id)
    #expect(Clerk.shared.deviceToken == "new-token")
    #expect(service.skipClientIdValues == [true])
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedEnvironment.rawValue))
  }

  @Test
  func updateDeviceTokenNeverPublishesNewTokenWithPreviousClient() async throws {
    configureClerkForTesting()
    Clerk.shared.cleanupManagers()

    let keychain = InMemoryKeychain()
    try keychain.set("old-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let oldClient = Client.mock
    let refreshedClient = Client(
      id: "refreshed-client",
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSince1970: 2000)
    )
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      clientService: DeviceTokenUpdateClientService(
        response: ClientServiceResponse(
          client: refreshedClient,
          requestSequence: 1,
          serverDate: Date(timeIntervalSince1970: 2000)
        )
      )
    )
    Clerk.shared.client = oldClient
    let observer = CoherentIdentityRecordingObserver()
    Clerk.shared.internalStateChanges.addObserver(observer)

    _ = try await Clerk.shared.updateDeviceToken("new-token")

    #expect(
      !observer.snapshots.contains {
        $0.deviceToken == "new-token" && $0.clientID == oldClient.id
      }
    )
    #expect(
      observer.snapshots.contains {
        $0.deviceToken == "new-token" && $0.clientID == nil
      }
    )
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

@MainActor
private final class CoherentIdentityRecordingObserver: ClerkInternalStateChangeObserver {
  struct Snapshot {
    let deviceToken: String?
    let clientID: String?
  }

  private(set) var snapshots: [Snapshot] = []

  func handle(_ change: ClerkInternalStateChange, from clerk: Clerk) throws {
    switch change {
    case .clientDidChange:
      guard !clerk.isApplyingSharedSessionIdentity else { return }
    case .deviceTokenDidChange, .sharedSessionIdentityDidChange:
      break
    case .environmentDidChange, .localStorageDidClear, .applicationDidEnterForeground:
      return
    }
    snapshots.append(Snapshot(deviceToken: clerk.deviceToken, clientID: clerk.client?.id))
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

private final class ThrowingInternalStateChangeObserver: ClerkInternalStateChangeObserver {
  enum Failure: Error {
    case failed
  }

  @MainActor
  func handle(_: ClerkInternalStateChange, from _: Clerk) throws {
    throw Failure.failed
  }
}
