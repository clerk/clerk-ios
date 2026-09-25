@testable import ClerkKit
import Foundation
import Testing

@MainActor
final class RecordingWatchSyncTransport: WatchSyncTransport {
  private(set) var sent: [WatchSyncPayload] = []

  func send(_ payload: WatchSyncPayload) {
    sent.append(payload)
  }
}

// MARK: - Payload

struct WatchSyncPayloadTests {
  @Test
  func completeStateRoundTrips() throws {
    let state = WatchSyncState(
      deviceToken: "token",
      client: signedIn("client"),
      serverDate: date(100),
      clearedAt: date(50)
    )
    let payload = WatchSyncPayload(state: state, environment: .mock)

    let decoded = try #require(WatchSyncPayload(applicationContext: payload.applicationContext))
    let decodedState = try #require(decoded.state)

    #expect(decodedState.deviceToken == "token")
    #expect(decodedState.client?.id == "client")
    #expect(decodedState.client?.lastActiveSessionId == state.client?.lastActiveSessionId)
    #expect(decodedState.serverDate == date(100))
    #expect(decodedState.clearedAt == date(50))
    #expect(decoded.environment == .mock)
  }

  @Test
  func clearedStateRoundTripsWithoutToken() throws {
    let state = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearedAt: date(50))
    let payload = WatchSyncPayload(state: state, environment: nil)

    let decoded = try #require(WatchSyncPayload(applicationContext: payload.applicationContext))

    #expect(decoded.state == state)
    #expect(decoded.state?.isCleared == true)
  }

  @Test
  func legacyPayloadWithTokenDecodesAsState() throws {
    let context: [String: Any] = try [
      "clerkDeviceToken": "legacy-token",
      "clerkClient": JSONEncoder.clerkEncoder.encode(signedIn("legacy-client")),
      "clerkClientServerFetchDate": 100.0,
      "watchSyncAuthVersion": 3,
    ]

    let state = try #require(WatchSyncPayload(applicationContext: context)?.state)

    #expect(state.deviceToken == "legacy-token")
    #expect(state.client?.id == "legacy-client")
    #expect(state.serverDate == date(100))
    #expect(state.clearedAt == nil)
  }

  @Test
  func legacyPayloadWithoutTokenCarriesNoState() throws {
    let clearOnly: [String: Any] = [
      "watchSyncDeviceTokenState": "cleared",
      "watchSyncDeviceTokenVersion": 4,
    ]
    let environmentOnly: [String: Any] = try [
      "watchSyncAuthState": "cleared",
      "clerkEnvironment": JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock),
    ]

    #expect(WatchSyncPayload(applicationContext: clearOnly) == nil)
    let payload = try #require(WatchSyncPayload(applicationContext: environmentOnly))
    #expect(payload.state == nil)
    #expect(payload.environment == .mock)
  }

  @Test
  func clientWithoutTokenIsRejected() {
    var context = WatchSyncPayload(
      state: WatchSyncState(deviceToken: "token", client: signedIn("client"), serverDate: date(100)),
      environment: nil
    ).applicationContext
    context["clerkDeviceToken"] = nil

    #expect(WatchSyncPayload(applicationContext: context) == nil)
  }

  @Test
  func undecodableClientIsRejectedInsteadOfTreatedAsSignedOut() {
    let context: [String: Any] = [
      "clerkWatchSyncSchema": 2,
      "clerkDeviceToken": "token",
      "clerkClient": Data("not json".utf8),
    ]

    #expect(WatchSyncPayload(applicationContext: context) == nil)
  }
}

// MARK: - Merge rule

struct WatchSyncStateMergeTests {
  @Test(arguments: [WatchSyncSource.phone, .watch])
  func sameTokenNewerSnapshotWinsFromEitherDevice(source: WatchSyncSource) {
    let local = WatchSyncState(deviceToken: "token", client: signedOut("client"), serverDate: date(100))
    let newer = WatchSyncState(deviceToken: "token", client: signedIn("client"), serverDate: date(200))
    let older = WatchSyncState(deviceToken: "token", client: signedIn("client"), serverDate: date(50))

    #expect(newer.supersedes(local, from: source))
    #expect(!older.supersedes(local, from: source))
  }

  @Test
  func sameTokenTieUsesClientUpdatedAt() {
    let local = WatchSyncState(deviceToken: "token", client: signedIn("client", updatedAt: 10), serverDate: date(100))
    let incoming = WatchSyncState(deviceToken: "token", client: signedIn("client", updatedAt: 20), serverDate: date(100))

    #expect(incoming.supersedes(local, from: .watch))
    #expect(!local.supersedes(incoming, from: .phone))
    #expect(!local.supersedes(local, from: .phone))
  }

  @Test
  func sameTokenSnapshotFillsMissingClientButNeverRemovesOne() {
    let tokenOnly = WatchSyncState(deviceToken: "token", client: nil, serverDate: nil)
    let snapshot = WatchSyncState(deviceToken: "token", client: signedIn("client"), serverDate: nil)

    #expect(snapshot.supersedes(tokenOnly, from: .watch))
    #expect(!tokenOnly.supersedes(snapshot, from: .phone))
  }

  @Test
  func onlyThePhoneCanClearTheOtherDevice() {
    let signedInState = WatchSyncState(deviceToken: "token", client: signedIn("client"), serverDate: date(100))
    let cleared = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearedAt: date(200))

    #expect(cleared.supersedes(signedInState, from: .phone))
    #expect(!cleared.supersedes(signedInState, from: .watch))
  }

  @Test(arguments: [WatchSyncSource.phone, .watch])
  func stateFromBeforeLocalClearIsRejected(source: WatchSyncSource) {
    let local = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearedAt: date(200))
    let stale = WatchSyncState(deviceToken: "old-token", client: signedIn("old"), serverDate: date(150))
    let fresh = WatchSyncState(deviceToken: "new-token", client: signedIn("new"), serverDate: date(250))

    #expect(!stale.supersedes(local, from: source))
    #expect(fresh.supersedes(local, from: source))
  }

  @Test
  func watchSeedsPhoneWithoutToken() {
    let phone = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil)
    let watch = WatchSyncState(deviceToken: "watch-token", client: signedIn("watch"), serverDate: date(100))

    #expect(watch.supersedes(phone, from: .watch))
  }

  @Test
  func signedInClientBeatsSignedOutClient() {
    let phone = WatchSyncState(deviceToken: "phone-token", client: signedOut("phone"), serverDate: date(200))
    let watch = WatchSyncState(deviceToken: "watch-token", client: signedIn("watch"), serverDate: date(100))

    #expect(watch.supersedes(phone, from: .watch))
    #expect(!phone.supersedes(watch, from: .phone))
  }

  @Test
  func phoneWinsWhenBothDevicesAreSignedIn() {
    let phone = WatchSyncState(deviceToken: "phone-token", client: signedIn("phone"), serverDate: date(100))
    let watch = WatchSyncState(deviceToken: "watch-token", client: signedIn("watch"), serverDate: date(200))

    #expect(phone.supersedes(watch, from: .phone))
    #expect(!watch.supersedes(phone, from: .watch))
  }
}

// MARK: - Coordinator

@MainActor
@Suite(.serialized)
struct WatchConnectivityCoordinatorTests {
  @Test
  func phoneStateReplacesWatchIdentity() throws {
    let (clerk, keychain) = try makeClerk(token: "watch-token", client: signedIn("watch"), serverDate: date(200))
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    coordinator.apply(payload(token: "phone-token", client: signedIn("phone"), serverDate: date(100)), from: .phone, to: clerk)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(clerk.client?.id == "phone")
  }

  @Test
  func watchClearDoesNotSignOutPhone() throws {
    let (clerk, keychain) = try makeClerk(token: "token", client: signedIn("phone"), serverDate: date(100))
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)

    coordinator.apply(
      WatchSyncPayload(state: WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearedAt: date(300)), environment: nil),
      from: .watch,
      to: clerk
    )

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "token")
    #expect(clerk.client?.id == "phone")
    // The phone's state predates the watch's clear, so the watch would reject it anyway.
    #expect(transport.sent.isEmpty)
  }

  @Test
  func rejectedStateRepliesWhenLocalStateWouldWin() throws {
    let (clerk, _) = try makeClerk(token: "phone-token", client: signedIn("phone"), serverDate: date(100))
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)

    coordinator.apply(payload(token: "watch-token", client: signedOut("watch"), serverDate: date(200)), from: .watch, to: clerk)

    #expect(clerk.client?.id == "phone")
    let reply = try #require(transport.sent.last?.state)
    #expect(reply.deviceToken == "phone-token")
    #expect(reply.client?.id == "phone")
  }

  @Test
  func equivalentStateIsNotEchoed() throws {
    let (clerk, _) = try makeClerk(token: "token", client: signedIn("client"), serverDate: date(100))
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)

    coordinator.apply(payload(token: "token", client: signedIn("client"), serverDate: date(100)), from: .watch, to: clerk)

    #expect(transport.sent.isEmpty)
  }

  @Test
  func adoptingTokenWithoutClientRefreshesClient() async throws {
    let refreshed = signedIn("refreshed")
    let (clerk, keychain) = try makeClerk(clientService: MockClientService { refreshed })
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    coordinator.apply(payload(token: "phone-token", client: nil, serverDate: nil), from: .phone, to: clerk)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    try await waitUntil { clerk.client?.id == "refreshed" }
  }

  @Test
  func adoptedPhoneClearBlocksOlderPhoneState() throws {
    let (clerk, keychain) = try makeClerk(token: "token", client: signedIn("client"), serverDate: date(100))
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    coordinator.apply(
      WatchSyncPayload(state: WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearedAt: date(200)), environment: nil),
      from: .phone,
      to: clerk
    )
    #expect(clerk.client == nil)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
    #expect(WatchSyncClearMarker.load(from: keychain) == date(200))

    coordinator.apply(payload(token: "token", client: signedIn("client"), serverDate: date(100)), from: .phone, to: clerk)
    #expect(clerk.client == nil)

    coordinator.apply(payload(token: "new-token", client: signedIn("new"), serverDate: date(300)), from: .phone, to: clerk)
    #expect(clerk.client?.id == "new")
  }

  @Test
  func localClearBlocksStateFromBeforeTheClear() throws {
    let (clerk, keychain) = try makeClerk()
    try WatchSyncClearMarker.record(date(200), in: keychain)
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    coordinator.apply(payload(token: "old-token", client: signedIn("old"), serverDate: date(150)), from: .watch, to: clerk)

    #expect(clerk.client == nil)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
  }

  @Test
  func localChangeSendsCompleteState() throws {
    let (clerk, keychain) = try makeClerk(token: "token", client: signedIn("client"), serverDate: date(100))
    try WatchSyncClearMarker.record(date(50), in: keychain)
    clerk.environment = .mock
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)

    try coordinator.handle(.clientDidChange(previous: nil, current: clerk.client), from: clerk)

    let sent = try #require(transport.sent.last)
    let state = try #require(sent.state)
    #expect(state.deviceToken == "token")
    #expect(state.client?.id == "client")
    #expect(state.serverDate == date(100))
    #expect(state.clearedAt == date(50))
    #expect(sent.environment == .mock)
  }

  @Test
  func remoteEnvironmentIsAppliedWithoutEcho() throws {
    let (clerk, _) = try makeClerk()
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    clerk.internalStateChanges.addObserver(coordinator)

    coordinator.apply(WatchSyncPayload(state: nil, environment: .mock), from: .phone, to: clerk)

    #expect(clerk.environment == .mock)
    #expect(transport.sent.isEmpty)
  }

  @Test
  func stoppedCoordinatorIgnoresPayloadsAndStopsSending() throws {
    let (clerk, _) = try makeClerk()
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    coordinator.stopAcceptingIdentityUpdates()

    coordinator.apply(payload(token: "token", client: signedIn("client"), serverDate: date(100)), from: .phone, to: clerk)
    try coordinator.handle(.applicationDidEnterForeground, from: clerk)

    #expect(clerk.client == nil)
    #expect(transport.sent.isEmpty)
  }

  private func makeClerk(
    token: String? = nil,
    client: Client? = nil,
    serverDate: Date? = nil,
    clientService: (any ClientServiceProtocol)? = nil
  ) throws -> (Clerk, InMemoryKeychain) {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    if let token {
      try keychain.set(token, forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    }
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      clientService: clientService ?? MockClientService(get: { throw CancellationError() })
    )
    try dependencies.configurationManager.configure(publishableKey: testPublishableKey, options: .init())
    clerk.dependencies = dependencies
    if let client {
      clerk.applyResponseClient(client, responseSequence: 1, serverDate: serverDate)
    }
    return (clerk, keychain)
  }

  private func payload(token: String, client: Client?, serverDate: Date?) -> WatchSyncPayload {
    WatchSyncPayload(
      state: WatchSyncState(deviceToken: token, client: client, serverDate: serverDate),
      environment: nil
    )
  }

  private func waitUntil(
    timeout: Duration = .milliseconds(500),
    condition: @MainActor () -> Bool
  ) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline, !condition() {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(condition())
  }
}

// MARK: - Fixtures

private func date(_ seconds: TimeInterval) -> Date {
  Date(timeIntervalSince1970: seconds)
}

private func signedIn(_ id: String, updatedAt: TimeInterval = 1000) -> Client {
  var client = Client.mock
  client.id = id
  client.updatedAt = date(updatedAt)
  return client
}

private func signedOut(_ id: String, updatedAt: TimeInterval = 1000) -> Client {
  var client = Client.mockSignedOut
  client.id = id
  client.updatedAt = date(updatedAt)
  return client
}
