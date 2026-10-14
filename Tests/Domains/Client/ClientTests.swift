@_spi(FrameworkIntegration) @testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClientTests {
  @Test
  func refreshClientRequestsTheClient() async throws {
    configureClerkForTesting()
    let called = LockIsolated(false)
    let expectedClient = Client(
      id: "refresh-client-test",
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let transport = FakeTransport.answeringClient {
      called.setValue(true)
      return expectedClient
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
    )
    Clerk.shared.client = nil

    _ = try await Clerk.shared.refreshClient()

    #expect(called.value == true)
    #expect(Clerk.shared.client?.id == expectedClient.id)
  }

  @Test
  func refreshClientPreservesClientWhenCanonicalResponseRequestsPreserve() async throws {
    configureClerkForTesting()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: FakeTransport.answeringClient { nil }
    )
    Clerk.shared.client = Client.mock

    let client = try await Clerk.shared.refreshClient()

    #expect(client?.id == Client.mock.id)
    #expect(Clerk.shared.client?.id == Client.mock.id)
  }

  @Test
  func refreshClientPreservesPersistedIdentityWhenCanonicalResponseRequestsPreserve() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: FakeTransport.answeringClient { nil },
      keychain: keychain
    )
    Clerk.shared.client = nil
    try Clerk.shared.seedIdentity(deviceToken: "current-token", client: Client.mock, serverDate: Date(timeIntervalSince1970: 100))

    let client = try await Clerk.shared.refreshClient()
    await Clerk.shared.waitForCacheWrites()

    let stored = try #require(try Clerk.shared.dependencies.identityStore.load())
    #expect(client?.id == Client.mock.id)
    #expect(Clerk.shared.client?.id == Client.mock.id)
    #expect(stored.state == .present)
    #expect(stored.deviceToken == "current-token")
    #expect(stored.client?.id == Client.mock.id)
    #expect(stored.serverDate == Date(timeIntervalSince1970: 100))
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
      transport: clientTransport(stale, requestSequence: 1)
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
      transport: clientTransport(nil, requestSequence: 1)
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
    try keychain.set(#require("cached-environment".data(using: .utf8)), forKey: ClerkKeychainKey.cachedEnvironment.rawValue)

    let expectedClient = Client(
      id: "updated-token-client",
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let transport = clientTransport(expectedClient, requestSequence: 1, serverDate: Date(timeIntervalSince1970: 2000))

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport,
      keychain: keychain
    )
    try Clerk.shared.seedIdentity(deviceToken: "old-token", client: Client.mock, serverDate: Date(timeIntervalSince1970: 100))

    let client = try await Clerk.shared.updateDeviceToken(" new-token\n")

    #expect(client?.id == expectedClient.id)
    #expect(Clerk.shared.client?.id == expectedClient.id)
    #expect(Clerk.shared.deviceToken == "new-token")
    #expect(skipClientIdValues(transport) == ["1"])
    await Clerk.shared.waitForCacheWrites()
    let stored = try #require(try Clerk.shared.dependencies.identityStore.load())
    #expect(stored.deviceToken == "new-token")
    #expect(stored.client?.id == expectedClient.id)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedEnvironment.rawValue))
  }

  @Test
  func updateDeviceTokenContinuesWhenInternalStateObserverThrows() async throws {
    configureClerkForTesting()
    Clerk.shared.cleanupManagers()

    let keychain = InMemoryKeychain()
    try keychain.set(#require("cached-environment".data(using: .utf8)), forKey: ClerkKeychainKey.cachedEnvironment.rawValue)

    let expectedClient = Client(
      id: "updated-token-client",
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let transport = clientTransport(expectedClient, requestSequence: 1, serverDate: Date(timeIntervalSince1970: 2000))

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport,
      keychain: keychain
    )
    try Clerk.shared.seedIdentity(deviceToken: "old-token", client: Client.mock, serverDate: Date(timeIntervalSince1970: 100))
    Clerk.shared.runtime.internalStateChanges.addObserver(ThrowingInternalStateChangeObserver())

    let client = try await Clerk.shared.updateDeviceToken(" new-token\n")

    #expect(client?.id == expectedClient.id)
    #expect(Clerk.shared.client?.id == expectedClient.id)
    #expect(Clerk.shared.deviceToken == "new-token")
    #expect(skipClientIdValues(transport) == ["1"])
    await Clerk.shared.waitForCacheWrites()
    let stored = try #require(try Clerk.shared.dependencies.identityStore.load())
    #expect(stored.deviceToken == "new-token")
    #expect(stored.client?.id == expectedClient.id)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedEnvironment.rawValue))
  }

  @Test
  func updateDeviceTokenNeverPublishesNewTokenWithPreviousClient() async throws {
    configureClerkForTesting()
    Clerk.shared.cleanupManagers()

    let keychain = InMemoryKeychain()
    let oldClient = Client.mock
    let refreshedClient = Client(
      id: "refreshed-client",
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSince1970: 2000)
    )
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: clientTransport(refreshedClient, requestSequence: 1, serverDate: Date(timeIntervalSince1970: 2000)),
      keychain: keychain
    )
    try Clerk.shared.seedIdentity(deviceToken: "old-token", client: oldClient)
    let observer = CoherentIdentityRecordingObserver()
    Clerk.shared.runtime.internalStateChanges.addObserver(observer)

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
    let transport = clientTransport(staleClient, requestSequence: 1, serverDate: Date(timeIntervalSince1970: 2000)) {
      try Clerk.shared.identityController.adoptDeviceToken("changed-token")
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
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

  @Test
  func setDeviceTokenReplacesMatchingTokenKeepingTheClientWithoutRefreshing() async throws {
    let refreshed = LockIsolated(false)
    let clerk = try makeDeviceTokenClerk(storedToken: "old-token", refreshed: refreshed)
    let previousGeneration = clerk.clientResponseGeneration

    let didSet = try await clerk.setDeviceToken(" new-token\n", expected: "old-token")
    await clerk.waitForCacheWrites()

    let stored = try #require(try clerk.dependencies.identityStore.load())
    #expect(didSet)
    #expect(clerk.deviceToken == "new-token")
    #expect(stored.deviceToken == "new-token")
    #expect(stored.client?.id == Client.mock.id)
    #expect(clerk.client?.id == Client.mock.id)
    #expect(clerk.clientResponseGeneration != previousGeneration)
    #expect(refreshed.value == false)
  }

  @Test
  func setDeviceTokenLeavesTheTokenUnchangedWhenExpectedTokenIsStale() async throws {
    let refreshed = LockIsolated(false)
    let clerk = try makeDeviceTokenClerk(storedToken: "current-token", refreshed: refreshed)
    let previousGeneration = clerk.clientResponseGeneration

    let didSet = try await clerk.setDeviceToken("new-token", expected: "stale-token")

    #expect(didSet == false)
    #expect(clerk.deviceToken == "current-token")
    #expect(try clerk.dependencies.identityStore.load()?.deviceToken == "current-token")
    #expect(clerk.client?.id == Client.mock.id)
    #expect(clerk.clientResponseGeneration == previousGeneration)
    #expect(refreshed.value == false)
  }

  @Test
  func setDeviceTokenWithNilExpectedOnlyStoresWhenNoTokenExists() async throws {
    let refreshed = LockIsolated(false)
    let clerk = try makeDeviceTokenClerk(storedToken: nil, refreshed: refreshed)

    #expect(try await clerk.setDeviceToken("first-token", expected: nil))
    #expect(try await clerk.setDeviceToken("second-token", expected: nil) == false)

    #expect(clerk.deviceToken == "first-token")
    #expect(try clerk.dependencies.identityStore.deviceToken() == "first-token")
    #expect(refreshed.value == false)
  }

  @Test
  func setDeviceTokenReportsSuccessWhenTheTokenAlreadyMatches() async throws {
    let refreshed = LockIsolated(false)
    let clerk = try makeDeviceTokenClerk(storedToken: "token", refreshed: refreshed)
    let previousGeneration = clerk.clientResponseGeneration

    #expect(try await clerk.setDeviceToken("token", expected: "token"))
    #expect(clerk.clientResponseGeneration == previousGeneration)
    #expect(refreshed.value == false)
  }

  @Test
  func setDeviceTokenClearsTheTokenAndClient() async throws {
    let refreshed = LockIsolated(false)
    let clerk = try makeDeviceTokenClerk(storedToken: "old-token", refreshed: refreshed)

    let didSet = try await clerk.setDeviceToken(nil, expected: "old-token")

    #expect(didSet)
    #expect(clerk.deviceToken == nil)
    #expect(try clerk.dependencies.identityStore.deviceToken() == nil)
    #expect(clerk.client == nil)
    #expect(refreshed.value == false)
  }

  @Test
  func setDeviceTokenRejectsBlankToken() async throws {
    let clerk = try makeDeviceTokenClerk(storedToken: "old-token", refreshed: LockIsolated(false))

    await #expect(throws: Clerk.DeviceTokenError.emptyToken) {
      try await clerk.setDeviceToken("   ", expected: "old-token")
    }
    #expect(try clerk.dependencies.identityStore.deviceToken() == "old-token")
  }

  private func makeDeviceTokenClerk(
    storedToken: String?,
    refreshed: LockIsolated<Bool>
  ) throws -> Clerk {
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      transport: FakeTransport.answeringClient {
        refreshed.setValue(true)
        return nil
      },
      keychain: InMemoryKeychain()
    )
    if let storedToken {
      try clerk.seedIdentity(deviceToken: storedToken, client: Client.mock, serverDate: Date(timeIntervalSince1970: 100))
    }
    return clerk
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
    case .clientDidChange, .deviceTokenDidChange, .identityDidChange:
      break
    case .environmentDidChange, .localStorageDidClear, .applicationDidEnterForeground:
      return
    }
    snapshots.append(Snapshot(deviceToken: clerk.deviceToken, clientID: clerk.client?.id))
  }
}

@MainActor
private func clientTransport(
  _ client: Client?,
  requestSequence: Int? = nil,
  serverDate: Date? = nil,
  beforeResponding: @escaping @MainActor () throws -> Void = {}
) -> FakeTransport {
  let transport = FakeTransport.mockDefaults()
  transport.stubReply(ClientAPI.get()) { _ in
    try beforeResponding()
    return FakeTransport.Reply(
      ClientResponse(response: client, client: nil),
      requestSequence: requestSequence,
      serverDate: serverDate
    )
  }
  return transport
}

@MainActor
private func skipClientIdValues(_ transport: FakeTransport) -> [String?] {
  transport.calls
    .filter { $0.path == "/v1/client" }
    .map { $0.headers[ClerkHeaderRequestMiddleware.skipClientIdHeader] }
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
