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
      clearGeneration: 3
    )
    let payload = WatchSyncPayload(state: state, environment: .mock)

    let decoded = try #require(WatchSyncPayload(applicationContext: payload.applicationContext))
    let decodedState = try #require(decoded.state)

    #expect(decodedState.deviceToken == "token")
    #expect(decodedState.client?.id == "client")
    #expect(decodedState.client?.lastActiveSessionId == state.client?.lastActiveSessionId)
    #expect(decodedState.serverDate == date(100))
    #expect(decodedState.clearGeneration == 3)
    #expect(decoded.environment == .mock)
  }

  @Test
  func clearedStateRoundTripsWithoutToken() throws {
    let state = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 2)
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
    #expect(state.clearGeneration == 0)
  }

  @Test
  func legacyClearDecodesAsAClearedStateAndOtherTokenlessPayloadsCarryNone() throws {
    let clear: [String: Any] = [
      "watchSyncDeviceTokenState": "cleared",
      "watchSyncDeviceTokenVersion": 4,
    ]
    let environmentOnly: [String: Any] = try [
      "watchSyncAuthState": "cleared",
      "clerkEnvironment": JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock),
    ]

    let clearState = try #require(WatchSyncPayload(applicationContext: clear)?.state)
    #expect(clearState.isCleared)
    #expect(clearState.clearGeneration == 0)
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
    let cleared = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil)

    #expect(cleared.supersedes(signedInState, from: .phone))
    #expect(!cleared.supersedes(signedInState, from: .watch))
  }

  @Test(arguments: [WatchSyncSource.phone, .watch])
  func stateFromBeforeAClearLosesWhateverItsServerDate(source: WatchSyncSource) {
    let local = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 1)
    // The server's clock is ahead of the device that cleared, so its date looks newer than the clear.
    let stale = WatchSyncState(deviceToken: "old-token", client: signedIn("old"), serverDate: .distantFuture)
    let afterClear = WatchSyncState(deviceToken: "new-token", client: signedOut("new"), serverDate: date(50), clearGeneration: 1)

    #expect(!stale.supersedes(local, from: source))
    #expect(afterClear.supersedes(local, from: source))
  }

  @Test
  func newerGenerationReplacesAnOlderSignedInState() {
    let staleWatch = WatchSyncState(deviceToken: "old-token", client: signedIn("old"), serverDate: date(300))
    let phoneAfterClear = WatchSyncState(deviceToken: "new-token", client: signedOut("new"), serverDate: date(100), clearGeneration: 1)

    #expect(phoneAfterClear.supersedes(staleWatch, from: .phone))
    #expect(!staleWatch.supersedes(phoneAfterClear, from: .watch))
  }

  @Test
  func onlyThePhoneCanClearAcrossGenerations() {
    let signedInState = WatchSyncState(deviceToken: "token", client: signedIn("client"), serverDate: date(100))
    let newerClear = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 1)

    #expect(newerClear.supersedes(signedInState, from: .phone))
    #expect(!newerClear.supersedes(signedInState, from: .watch))
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

    #expect(clerk.identityController.currentDeviceToken == "phone-token")
    #expect(clerk.client?.id == "phone")
  }

  @Test
  func watchClearDoesNotSignOutPhoneButItsGenerationIsLearned() throws {
    let (clerk, keychain) = try makeClerk(token: "token", client: signedIn("phone"), serverDate: date(100))
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)

    coordinator.apply(
      WatchSyncPayload(state: WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 1), environment: nil),
      from: .watch,
      to: clerk
    )

    #expect(clerk.identityController.currentDeviceToken == "token")
    #expect(clerk.client?.id == "phone")
    #expect(WatchSyncClearMarker.generation(in: keychain) == 1)
    // The reply carries the learned generation, so the watch adopts the phone's state.
    let reply = try #require(transport.sent.last?.state)
    #expect(reply.deviceToken == "token")
    #expect(reply.clearGeneration == 1)
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

    #expect(clerk.identityController.currentDeviceToken == "phone-token")
    try await waitUntil { clerk.client?.id == "refreshed" }
  }

  @Test
  func adoptedPhoneClearBlocksStateFromBeforeIt() throws {
    let (clerk, keychain) = try makeClerk(token: "token", client: signedIn("client"), serverDate: date(100))
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    coordinator.apply(
      WatchSyncPayload(state: WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 1), environment: nil),
      from: .phone,
      to: clerk
    )
    #expect(clerk.client == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
    #expect(WatchSyncClearMarker.generation(in: keychain) == 1)

    coordinator.apply(payload(token: "token", client: signedIn("client"), serverDate: .distantFuture), from: .phone, to: clerk)
    #expect(clerk.client == nil)

    coordinator.apply(payload(token: "new-token", client: signedIn("new"), serverDate: date(50), generation: 1), from: .phone, to: clerk)
    #expect(clerk.client?.id == "new")
  }

  @Test
  func localClearBlocksStateFromBeforeTheClear() throws {
    let (clerk, keychain) = try makeClerk()
    try WatchSyncClearMarker.record(in: keychain)
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    coordinator.apply(payload(token: "old-token", client: signedIn("old"), serverDate: .distantFuture), from: .watch, to: clerk)

    #expect(clerk.client == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
  }

  @Test
  func clearRecordedBySDK15IsHonoredAfterUpgrading() throws {
    let (clerk, keychain) = try makeClerk()
    try keychain.set(
      Data(#"{"device_token_state":"cleared","device_token_version":1726000000000,"auth_state":"cleared","auth_version":1726000000000}"#.utf8),
      forKey: ClerkKeychainKey.watchSyncMetadata.rawValue
    )
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    coordinator.apply(payload(token: "pre-clear-token", client: signedIn("old"), serverDate: .distantFuture), from: .watch, to: clerk)

    #expect(WatchSyncClearMarker.generation(in: keychain) == 1)
    #expect(clerk.client == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
  }

  @Test
  func localChangeSendsCompleteState() throws {
    let (clerk, keychain) = try makeClerk(token: "token", client: signedIn("client"), serverDate: date(100))
    try WatchSyncClearMarker.record(in: keychain)
    clerk.environment = .mock
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)

    try coordinator.handle(.clientDidChange(previous: nil, current: clerk.client), from: clerk)

    let sent = try #require(transport.sent.last)
    let state = try #require(sent.state)
    #expect(state.deviceToken == "token")
    #expect(state.client?.id == "client")
    #expect(state.serverDate == date(100))
    #expect(state.clearGeneration == 1)
    #expect(sent.environment == .mock)
  }

  @Test
  func environmentFromTheWatchIsIgnored() throws {
    let (clerk, _) = try makeClerk(token: "phone-token", client: signedIn("phone"), serverDate: date(100))
    var phoneEnvironment = Clerk.Environment.mock
    phoneEnvironment.displayConfig.applicationName = "Phone"
    clerk.environment = phoneEnvironment
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)

    coordinator.apply(
      WatchSyncPayload(
        state: WatchSyncState(deviceToken: "watch-token", client: signedOut("watch"), serverDate: date(200)),
        environment: .mock
      ),
      from: .watch,
      to: clerk
    )

    #expect(clerk.environment?.displayConfig.applicationName == "Phone")
    #expect(transport.sent.last?.environment?.displayConfig.applicationName == "Phone")
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

  private func payload(token: String, client: Client?, serverDate: Date?, generation: Int = 0) -> WatchSyncPayload {
    WatchSyncPayload(
      state: WatchSyncState(deviceToken: token, client: client, serverDate: serverDate, clearGeneration: generation),
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
