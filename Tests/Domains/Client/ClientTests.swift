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
  func refreshClientPreservesClientWhenCanonicalResponseRequestsPreserve() async throws {
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
  func refreshClientPreservesPersistedIdentityWhenCanonicalResponseRequestsPreserve() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      clientService: MockClientService(get: { nil })
    )
    Clerk.shared.client = nil
    try Clerk.shared.seedIdentity(deviceToken: "current-token", client: Client.mock, serverDate: Date(timeIntervalSince1970: 100))

    let client = try await Clerk.shared.refreshClient()

    let stored = try #require(try Clerk.shared.dependencies.identityStore.load()?.identity)
    #expect(client?.id == Client.mock.id)
    #expect(Clerk.shared.client?.id == Client.mock.id)
    #expect(stored.state == .present)
    #expect(stored.deviceToken == "current-token")
    #expect(stored.client?.id == Client.mock.id)
    #expect(stored.serverDate == Date(timeIntervalSince1970: 100))
  }

  @Test
  func refreshClientIgnoresStaleClientResponseSequence() async throws {
    try await checkOutOfOrderRefresh(firstResponse: .mockSignedOut)
  }

  @Test
  func refreshClientIgnoresStaleNilResponseSequence() async throws {
    try await checkOutOfOrderRefresh(firstResponse: nil)
  }

  private func checkOutOfOrderRefresh(firstResponse: Client?) async throws {
    configureClerkForTesting()
    let service = MockClientService()
    let expected = Client.mock
    var suspended: CheckedContinuation<MockClientService.Response, any Error>?
    var calls = 0
    service.responseHandler = { _ in
      calls += 1
      if calls == 1 { return try await withCheckedThrowingContinuation { suspended = $0 } }
      return .init(client: expected, serverDate: nil)
    }
    Clerk.shared.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(), clientService: service)
    try Clerk.shared.seedIdentity(deviceToken: "token", client: .mockSignedOut)
    let first = Task { try await Clerk.shared.refreshClient() }
    let deadline = ContinuousClock.now + .seconds(1)
    while suspended == nil, ContinuousClock.now < deadline {
      await Task.yield()
    }
    let continuation = try #require(suspended)
    _ = try await Clerk.shared.refreshClient()
    continuation.resume(returning: .init(client: firstResponse, serverDate: nil))
    let result = try await first.value
    // HTTP encoding rounds fixture dates to milliseconds; compare the identity and sessions.
    #expect(result?.id == expected.id)
    #expect(result?.sessions.map(\.id) == expected.sessions.map(\.id))
    #expect(result == Clerk.shared.client)
    #expect(try Clerk.shared.dependencies.identityStore.load()?.identity.client == Clerk.shared.client)
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
    let service = MockClientService()
    var capturedRequests: [URLRequest] = []
    service.responseHandler = { request in
      capturedRequests.append(request)
      return .init(client: expectedClient, serverDate: Date(timeIntervalSince1970: 2000))
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      clientService: service
    )
    try Clerk.shared.seedIdentity(deviceToken: "old-token", client: Client.mock, serverDate: Date(timeIntervalSince1970: 100))

    let client = try await Clerk.shared.updateDeviceToken(" new-token\n")

    #expect(client?.id == expectedClient.id)
    #expect(Clerk.shared.client?.id == expectedClient.id)
    #expect(Clerk.shared.deviceToken == "new-token")
    #expect(capturedRequests.count == 1)
    #expect(capturedRequests.first?.value(forHTTPHeaderField: "x-clerk-client-id") == nil)
    #expect(capturedRequests.first?.value(forHTTPHeaderField: "Authorization") == "new-token")
    let stored = try #require(try Clerk.shared.dependencies.identityStore.load()?.identity)
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
    let service = MockClientService()
    var capturedRequests: [URLRequest] = []
    service.responseHandler = { request in
      capturedRequests.append(request)
      return .init(client: expectedClient, serverDate: Date(timeIntervalSince1970: 2000))
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      clientService: service
    )
    try Clerk.shared.seedIdentity(deviceToken: "old-token", client: Client.mock, serverDate: Date(timeIntervalSince1970: 100))
    Clerk.shared.internalStateChanges.addObserver(ThrowingInternalStateChangeObserver())

    let client = try await Clerk.shared.updateDeviceToken(" new-token\n")

    #expect(client?.id == expectedClient.id)
    #expect(Clerk.shared.client?.id == expectedClient.id)
    #expect(Clerk.shared.deviceToken == "new-token")
    #expect(capturedRequests.count == 1)
    #expect(capturedRequests.first?.value(forHTTPHeaderField: "x-clerk-client-id") == nil)
    #expect(capturedRequests.first?.value(forHTTPHeaderField: "Authorization") == "new-token")
    let stored = try #require(try Clerk.shared.dependencies.identityStore.load()?.identity)
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
      keychain: keychain,
      clientService: MockClientService { refreshedClient }
    )
    try Clerk.shared.seedIdentity(deviceToken: "old-token", client: oldClient)
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
    let service = MockClientService {
      _ = try await Clerk.shared.identityController.updateDeviceToken(to: "changed-token")
      return staleClient
    }

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
    case .clientDidChange, .deviceTokenDidChange, .identityDidChange:
      break
    case .environmentDidChange, .localStorageDidClear, .applicationDidEnterForeground:
      return
    }
    snapshots.append(Snapshot(deviceToken: clerk.deviceToken, clientID: clerk.client?.id))
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
