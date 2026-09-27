@_spi(FrameworkIntegration) @testable import ClerkKit
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
  func payloadAlsoCarriesTheVersionedKeysAnSDK15PeerNeeds() throws {
    // The coordinator persists each version before constructing the payload.
    let signedInContext = WatchSyncPayload(
      state: WatchSyncState(deviceToken: "token", client: signedIn("client"), serverDate: date(100)),
      environment: nil, legacyVersion: .init(token: 1, auth: 1)
    ).applicationContext
    #expect(signedInContext["watchSyncDeviceTokenState"] as? String == "set")
    #expect(signedInContext["watchSyncAuthState"] as? String == "set")
    let version = try #require(signedInContext["watchSyncAuthVersion"] as? Int)
    #expect(version == 1)

    let clearedContext = WatchSyncPayload(
      state: WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 1),
      environment: nil, legacyVersion: .init(token: 2, auth: 2)
    ).applicationContext
    #expect(clearedContext["watchSyncDeviceTokenState"] as? String == "cleared")
    #expect(clearedContext["watchSyncAuthState"] as? String == "cleared")

    // A device that has not fetched a token yet must not sign out an SDK 1.5 peer.
    let freshContext = WatchSyncPayload(
      state: WatchSyncState(deviceToken: nil, client: nil, serverDate: nil),
      environment: nil
    ).applicationContext
    #expect(freshContext["watchSyncDeviceTokenState"] == nil)
    #expect(freshContext["watchSyncAuthState"] == nil)
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
      "watchSyncAuthState": "set",
      "watchSyncAuthVersion": 3,
    ]

    let state = try #require(WatchSyncPayload(applicationContext: context)?.state)

    #expect(state.deviceToken == "legacy-token")
    #expect(state.client?.id == "legacy-client")
    #expect(state.serverDate == date(100))
    #expect(state.clearGeneration == 0)
  }

  @Test
  func legacyPayloadRequiresAnExplicitVersionedTokenClear() throws {
    let clear: [String: Any] = [
      "watchSyncDeviceTokenState": "cleared",
      "watchSyncDeviceTokenVersion": 4,
    ]
    let environmentOnly: [String: Any] = try [
      "watchSyncAuthState": "cleared",
      "clerkEnvironment": JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock),
    ]

    #expect(WatchSyncPayload(applicationContext: clear)?.state?.isCleared == true)
    #expect(WatchSyncPayload(applicationContext: ["watchSyncDeviceTokenState": "cleared"]) == nil)
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
  @Test
  @MainActor
  func oldWatchSnapshotCannotReplacePhoneTokenWhileItsRefreshIsPending() async throws {
    let phone = Clerk()
    phone.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(runtimeScope: phone.runtimeScope))
    try phone.seedIdentity(deviceToken: "old-token", client: signedIn("old-client"), serverDate: date(100))
    let oldWatch = try WatchSyncState(of: phone)
    #expect(try await phone.identityController.updateDeviceToken(to: "new-token") == .applied)
    let generation = phone.clientResponseGeneration
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    coordinator.apply(WatchSyncPayload(state: oldWatch, environment: nil), from: .watch, to: phone)

    #expect(phone.deviceToken == "new-token")
    #expect(phone.client == nil)
    #expect(phone.clientResponseGeneration == generation)
    // The Watch can retain its signed-in snapshot while the phone resolves the new token.
    #expect(try !WatchSyncState(of: phone).supersedes(oldWatch, from: .phone))
    try await phone.identityController.applyNetworkResponse(ClientSyncResponseContext(
      update: .client(signedIn("new-client")), deviceTokenUpdate: .absent,
      requestDeviceToken: "new-token", serverDate: date(200), isCanonicalClientRequest: true,
      clientResponseGeneration: generation, responseSequence: 1
    ))
    #expect(phone.deviceToken == "new-token")
    #expect(phone.client?.id == "new-client")
    #expect(try WatchSyncState(of: phone).supersedes(oldWatch, from: .phone))
  }

  @Test
  func newerClearStillReplacesAnUnresolvedPhoneIdentity() {
    let phone = WatchSyncState(deviceToken: "new-token", client: nil, serverDate: nil)
    let clear = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 1)
    #expect(clear.supersedes(phone, from: .watch))
    #expect(!phone.supersedes(clear, from: .phone))
  }

  @Test(arguments: [Session.SessionStatus.ended, .expired, .removed, .replaced, .abandoned], [false, true])
  func terminalPhoneSessionsDoNotDefeatAnActiveOrPendingWatch(status: Session.SessionStatus, pending: Bool) {
    var phoneClient = signedIn("phone")
    phoneClient.sessions = phoneClient.sessions.map { var session = $0; session.status = status; return session }
    var watchClient = signedIn("watch")
    watchClient.sessions = watchClient.sessions.map { var session = $0; session.status = pending ? .pending : .active; return session }
    let phone = WatchSyncState(deviceToken: "phone-token", client: phoneClient, serverDate: date(200))
    let watch = WatchSyncState(deviceToken: "watch-token", client: watchClient, serverDate: date(100))
    #expect(!phone.hasSession)
    #expect(watch.hasSession)
    #expect(watch.supersedes(phone, from: .watch))
    #expect(!phone.supersedes(watch, from: .phone))
  }

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

  @Test(arguments: [WatchSyncSource.phone, .watch], [false, true])
  func tokenRotationForTheSameClientFollowsSnapshotFreshness(source: WatchSyncSource, signingOut: Bool) {
    let older = WatchSyncState(deviceToken: "old-token", client: signingOut ? signedIn("client") : signedOut("client"),
                               serverDate: date(100))
    let newer = WatchSyncState(deviceToken: "rotated-token", client: signingOut ? signedOut("client") : signedIn("client"),
                               serverDate: date(200))

    #expect(newer.supersedes(older, from: source))
    #expect(!older.supersedes(newer, from: source))
  }

  @Test
  func tokenRotationUsesClientUpdatedAtBeforeThePhoneTieBreaker() {
    let phone = WatchSyncState(deviceToken: "phone-token", client: signedIn("client", updatedAt: 10), serverDate: date(100))
    let watch = WatchSyncState(deviceToken: "watch-token", client: signedOut("client", updatedAt: 20), serverDate: date(100))

    #expect(watch.supersedes(phone, from: .watch))
    #expect(!phone.supersedes(watch, from: .phone))
  }

  @Test
  func phoneTokenWinsBetweenEquallyNewSnapshotsOfOneClient() {
    let phone = WatchSyncState(deviceToken: "phone-token", client: signedIn("client"), serverDate: date(100))
    let watch = WatchSyncState(deviceToken: "watch-token", client: signedIn("client"), serverDate: date(100))

    #expect(phone.supersedes(watch, from: .phone))
    #expect(!watch.supersedes(phone, from: .watch))
    #expect(!phone.supersedes(phone, from: .phone))
  }

  @Test
  func phoneWithoutATokenYetDoesNotClearASignedInWatch() {
    let watch = WatchSyncState(deviceToken: "watch-token", client: signedIn("watch"), serverDate: date(100))
    let freshPhone = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil)

    #expect(!freshPhone.supersedes(watch, from: .phone))
    #expect(watch.supersedes(freshPhone, from: .watch))
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
  func eitherDeviceCanClearAcrossGenerations() {
    let signedInState = WatchSyncState(deviceToken: "token", client: signedIn("client"), serverDate: date(100))
    let newerClear = WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 1)

    #expect(newerClear.supersedes(signedInState, from: .phone))
    #expect(newerClear.supersedes(signedInState, from: .watch))
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

  @Test(arguments: [false, true])
  func aNewerWatchClearGenerationReplacesThePreClearPhoneIdentity(watchHasSession: Bool) {
    let phone = WatchSyncState(deviceToken: "phone-token", client: signedIn("phone"), serverDate: date(100))
    let watch = WatchSyncState(deviceToken: "watch-token", client: watchHasSession ? signedIn("watch") : signedOut("watch"),
                               serverDate: date(200), clearGeneration: 1)

    #expect(watch.supersedes(phone, from: .watch))
    #expect(!phone.supersedes(watch, from: .phone))
  }

  @Test
  func sameTokenWatchSignOutStillUpdatesThePhone() {
    let phone = WatchSyncState(deviceToken: "token", client: signedIn("client"), serverDate: date(100))
    let watch = WatchSyncState(deviceToken: "token", client: signedOut("client"), serverDate: date(200))

    #expect(watch.supersedes(phone, from: .watch))
  }
}

// MARK: - Coordinator

@MainActor
@Suite(.serialized)
struct WatchConnectivityCoordinatorTests {
  @Test(arguments: [false, true], [false, true])
  func clearingPreservesPhoneReceiveHistoryBeforeItsFirstCurrentPayload(reconfiguration: Bool, restarts: Bool) throws {
    let (clerk, keychain) = try makeClerk(token: "old-token", client: signedIn("old"))
    try keychain.set(JSONSerialization.data(withJSONObject: [
      "device_token_version": 100, "device_token_source": "phone",
      "auth_version": 100, "auth_source": "phone",
      "pending_device_token_version": 500, "pending_device_token_source": "phone",
      "pending_auth_version": 500, "pending_auth_source": "phone",
    ]), forKey: ClerkKeychainKey.watchSyncMetadata.rawValue)
    try #require(try clerk.dependencies.identityStore.load()?.watchPhoneOrdering == nil)
    if reconfiguration {
      try Clerk.clearLocalClerkStorageStrictly(in: clerk.dependencies)
      clerk.identityController.prepareForConfiguration()
      clerk.identityController.hydrate()
    } else {
      try clerk.clearKeychainItems()
    }
    #expect(try keychain.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue) == nil)
    try clerk.seedIdentity(deviceToken: "new-token", client: signedIn("new"))
    let receiver: Clerk
    if restarts {
      receiver = Clerk()
      receiver.dependencies = clerk.dependencies
      receiver.identityController.hydrate()
    } else {
      receiver = clerk
    }
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    try coordinator.apply(legacyPayload(token: nil, version: 99), from: .phone, to: receiver)
    #expect(receiver.deviceToken == "new-token")
    #expect(receiver.client?.id == "new")
    try coordinator.apply(legacyPayload(token: nil, version: 100), from: .phone, to: receiver)
    #expect(receiver.deviceToken == "new-token")
    // A pending version was never accepted; it must not block a newer committed message.
    try coordinator.apply(legacyPayload(token: nil, version: 101), from: .phone, to: receiver)
    #expect(receiver.deviceToken == nil)
    #expect(receiver.client == nil)
  }

  @Test
  func outboundPhoneClearsAndLaterSignInsKeepLegacyOrderingAcrossRestart() throws {
    let (clerk, keychain) = try makeClerk(token: "old-token", client: signedIn("old"), serverDate: date(100))
    let previousVersion = 2_000_000_000
    try keychain.set(JSONSerialization.data(withJSONObject: [
      "device_token_version": previousVersion - 2, "auth_version": previousVersion - 1,
      "pending_auth_version": previousVersion,
    ]), forKey: ClerkKeychainKey.watchSyncMetadata.rawValue)
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    clerk.internalStateChanges.addObserver(coordinator)
    coordinator.sync(from: clerk)
    let before = try #require(transport.sent.last?.applicationContext)
    let beforeVersion = try #require(before["watchSyncDeviceTokenVersion"] as? Int)
    #expect(beforeVersion > previousVersion)
    #expect(before["watchSyncDeviceTokenState"] as? String == "set")
    try clerk.clearKeychainItems()
    let clear = try #require(transport.sent.last?.applicationContext)
    let clearVersion = try #require(clear["watchSyncDeviceTokenVersion"] as? Int)
    #expect(clear["watchSyncDeviceTokenState"] as? String == "cleared")
    #expect(clear["watchSyncAuthState"] as? String == "cleared")
    #expect(clear["watchSyncAuthVersion"] as? Int == clearVersion)
    #expect(clearVersion > beforeVersion)
    clerk.identityController.prepareForConfiguration()
    clerk.identityController.hydrate()
    let restarted = WatchConnectivityCoordinator(transport: transport)
    restarted.sync(from: clerk)
    #expect(transport.sent.last?.applicationContext["watchSyncDeviceTokenVersion"] as? Int == clearVersion)
    try clerk.seedIdentity(deviceToken: "new-token", client: signedIn("new"), serverDate: date(200))
    restarted.sync(from: clerk)
    let login = try #require(transport.sent.last?.applicationContext)
    let loginVersion = try #require(login["watchSyncDeviceTokenVersion"] as? Int)
    #expect(loginVersion > clearVersion)
    #expect(login["watchSyncDeviceTokenState"] as? String == "set")
    #expect(login["watchSyncAuthState"] as? String == "set")
    #expect(login["watchSyncAuthVersion"] as? Int == loginVersion)
  }

  @Test
  func legacyPhoneClearIsOrderedAcrossRestartAndLaterSignIn() throws {
    let (clerk, keychain) = try makeClerk(token: "old-token", client: signedIn("old"), serverDate: date(100))
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    let clear = try legacyPayload(token: nil, version: 2)
    coordinator.apply(clear, from: .watch, to: clerk)
    #expect(clerk.deviceToken == "old-token")
    coordinator.apply(clear, from: .phone, to: clerk)
    #expect(clerk.deviceToken == nil)
    #expect(clerk.client?.id == nil)
    #expect(try WatchSyncClearMarker.generation(in: keychain) == 1)
    clerk.identityController.prepareForConfiguration()
    clerk.identityController.hydrate()
    coordinator.apply(clear, from: .phone, to: clerk)
    try coordinator.apply(legacyPayload(token: "old-token", version: 1), from: .phone, to: clerk)
    #expect(clerk.deviceToken == nil)
    #expect(try WatchSyncClearMarker.generation(in: keychain) == 1)
    try coordinator.apply(legacyPayload(token: "new-token", version: 3), from: .phone, to: clerk)
    #expect(clerk.deviceToken == "new-token")
    coordinator.apply(clear, from: .phone, to: clerk)
    #expect(clerk.deviceToken == "new-token")
    try coordinator.apply(legacyPayload(token: nil, version: 4), from: .phone, to: clerk)
    #expect(clerk.deviceToken == nil)
    #expect(try WatchSyncClearMarker.generation(in: keychain) == 2)
  }

  @Test(arguments: ["phone", "watch"])
  func legacyClearRespectsThePreviouslyAcceptedPhoneVersions(previousSource: String) throws {
    let (clerk, keychain) = try makeClerk(token: "token", client: signedIn("client"))
    try keychain.set(JSONSerialization.data(withJSONObject: [
      "device_token_version": 4, "device_token_source": previousSource,
      "auth_version": 4, "auth_source": previousSource,
      "pending_device_token_version": 5, "pending_device_token_source": "phone",
      "pending_auth_version": 5, "pending_auth_source": "phone",
    ]), forKey: ClerkKeychainKey.watchSyncMetadata.rawValue)
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    try coordinator.apply(legacyPayload(token: nil, version: 3), from: .phone, to: clerk)
    #expect(clerk.deviceToken == (previousSource == "phone" ? "token" : nil))
    try coordinator.apply(legacyPayload(token: nil, version: 5, authVersion: 3), from: .phone, to: clerk)
    #expect(clerk.deviceToken == (previousSource == "phone" ? "token" : nil))
    try coordinator.apply(legacyPayload(token: nil, version: 5), from: .phone, to: clerk)
    #expect(clerk.deviceToken == nil)
  }

  @Test(arguments: [false, true])
  func currentPhoneSchemaClosesTheLegacyStreamWithoutInventingAClear(hasToken: Bool) throws {
    let (clerk, keychain) = try makeClerk(token: hasToken ? "token" : nil, client: hasToken ? signedIn("client") : nil)
    let before = try clerk.dependencies.identityStore.load()
    let state = try WatchSyncState(of: clerk)
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    coordinator.apply(.init(state: state, environment: nil), from: .phone, to: clerk)
    let stored = try #require(try clerk.dependencies.identityStore.load())
    #expect(stored.watchPhoneOrdering?[clerk.dependencies.identityStore.watchSyncOwnerIdentifier]?.usesCurrentSchema == true)
    #expect(stored.clearEpoch == before?.clearEpoch)
    if let before { #expect(stored.epoch == before.epoch) }
    clerk.identityController.prepareForConfiguration()
    clerk.identityController.hydrate()
    try coordinator.apply(legacyPayload(token: nil, version: 99), from: .phone, to: clerk)
    #expect(clerk.deviceToken == (hasToken ? "token" : nil))
    #expect(try WatchSyncClearMarker.generation(in: keychain) == state.clearGeneration)
  }

  private func legacyPayload(token: String?, version: Int, authVersion: Int? = nil) throws -> WatchSyncPayload {
    var context: [String: Any] = [
      "watchSyncDeviceTokenState": token == nil ? "cleared" : "set", "watchSyncDeviceTokenVersion": version,
      "watchSyncAuthState": token == nil ? "cleared" : "set", "watchSyncAuthVersion": authVersion ?? version,
    ]
    if let token {
      context["clerkDeviceToken"] = token
      context["clerkClient"] = try JSONEncoder.clerkEncoder.encode(signedIn(token))
      context["clerkClientServerFetchDate"] = Double(version * 100)
    }
    return try #require(WatchSyncPayload(applicationContext: context))
  }

  @Test(arguments: [WatchSyncSource.phone, .watch])
  func signOutWithARotatedTokenReachesThePeerAndSurvivesRestart(source: WatchSyncSource) throws {
    let (clerk, _) = try makeClerk(token: "old-token", client: signedIn("client"), serverDate: date(100))
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    coordinator.apply(payload(token: "rotated-token", client: signedOut("client"), serverDate: date(200)), from: source, to: clerk)

    #expect(clerk.deviceToken == "rotated-token")
    #expect(clerk.client?.sessions.isEmpty == true)
    let restarted = Clerk()
    restarted.dependencies = clerk.dependencies
    restarted.identityController.hydrate()
    #expect(restarted.deviceToken == "rotated-token")
    #expect(restarted.client?.id == "client")
    #expect(restarted.client?.sessions.isEmpty == true)
  }

  @Test
  func watchAnonymousIdentityAfterLocalClearSignsOutThePhone() throws {
    let (phone, _) = try makeClerk(token: "phone-token", client: signedIn("phone"), serverDate: date(100))
    let (watch, _) = try makeClerk(token: "phone-token", client: signedIn("phone"), serverDate: date(100))
    let phoneTransport = RecordingWatchSyncTransport()
    let watchTransport = RecordingWatchSyncTransport()
    let phoneCoordinator = WatchConnectivityCoordinator(transport: phoneTransport)
    let watchCoordinator = WatchConnectivityCoordinator(transport: watchTransport)
    let beforeClear = try WatchSyncPayload(state: WatchSyncState(of: phone), environment: nil)
    try watch.identityController.clearIdentity()
    // A normal refresh after clearing creates a new anonymous server-side Client.
    try watch.seedIdentity(deviceToken: "watch-anonymous", client: signedOut("watch"), serverDate: date(200))
    watchCoordinator.sync(from: watch)
    let anonymous = try #require(watchTransport.sent.last)
    #expect(try #require(anonymous.state?.clearGeneration) > WatchSyncState(of: phone).clearGeneration)

    phoneCoordinator.apply(anonymous, from: .watch, to: phone)

    #expect(phone.deviceToken == "watch-anonymous")
    #expect(phone.client?.sessions.isEmpty == true)
    phoneCoordinator.sync(from: phone)
    let reply = try #require(phoneTransport.sent.last)
    #expect(reply.state?.clearGeneration == anonymous.state?.clearGeneration)
    watchCoordinator.apply(reply, from: .phone, to: watch)
    #expect(watch.deviceToken == "watch-anonymous")
    #expect(watch.client?.sessions.isEmpty == true)
    watchCoordinator.apply(beforeClear, from: .phone, to: watch)
    #expect(watch.deviceToken == "watch-anonymous")
    phoneCoordinator.apply(anonymous, from: .watch, to: phone)
    #expect(phone.deviceToken == "watch-anonymous")
    #expect(phone.client?.sessions.isEmpty == true)
  }

  @Test
  func phoneStateReplacesWatchIdentity() throws {
    let (clerk, keychain) = try makeClerk(token: "watch-token", client: signedIn("watch"), serverDate: date(200))
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    coordinator.apply(payload(token: "phone-token", client: signedIn("phone"), serverDate: date(100)), from: .phone, to: clerk)

    #expect(clerk.identityController.currentDeviceToken == "phone-token")
    #expect(clerk.client?.id == "phone")
  }

  @Test
  func watchClearSignsOutPhoneAndPersistsItsGeneration() throws {
    let (clerk, keychain) = try makeClerk(token: "token", client: signedIn("phone"), serverDate: date(100))
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)

    coordinator.apply(
      WatchSyncPayload(state: WatchSyncState(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 1), environment: nil),
      from: .watch,
      to: clerk
    )

    #expect(clerk.identityController.currentDeviceToken == nil)
    #expect(clerk.client == nil)
    #expect(try WatchSyncClearMarker.generation(in: keychain) == 1)
    #expect(try clerk.dependencies.identityStore.load()?.watchClearGeneration == 1)
    #expect(try clerk.dependencies.identityStore.load()?.identity == .signedOut)
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

    #expect(clerk.identityController.currentDeviceToken == "phone-token")
    try await waitUntil { clerk.client?.id == "refreshed" }
  }

  enum RefreshTransition: CaseIterable {
    case localClear, phoneClear, phoneTokenReplacement
  }

  @Test(arguments: RefreshTransition.allCases, [false, true])
  func replacementRefreshSurvivesAnObsoleteTaskFinishing(transition: RefreshTransition, stopBeforeCompletion: Bool) async throws {
    let service = SuspendedWatchClientService()
    let (clerk, _) = try makeClerk(clientService: service)
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    clerk.internalStateChanges.addObserver(coordinator)
    defer {
      clerk.cleanupManagers()
      service.cancelPendingRequests()
    }
    coordinator.apply(payload(token: "old-token", client: nil, serverDate: nil), from: .phone, to: clerk)
    try await waitUntil { service.calls == 1 }
    let obsoleteTask = try #require(coordinator.refreshTask)

    switch transition {
    case .localClear:
      try clerk.clearKeychainItems()
    case .phoneClear:
      coordinator.apply(WatchSyncPayload(
        state: .init(deviceToken: nil, client: nil, serverDate: nil, clearGeneration: 1), environment: nil
      ), from: .phone, to: clerk)
    case .phoneTokenReplacement:
      break
    }
    let generation = transition == .phoneTokenReplacement ? 0 : 1
    coordinator.apply(payload(token: "new-token", client: nil, serverDate: nil, generation: generation), from: .phone, to: clerk)
    try await waitUntil { service.calls == 2 }
    let replacementTask = try #require(coordinator.refreshTask)
    try #require(service.calls == 2)
    #expect(obsoleteTask.isCancelled)

    // Simulate a transport that finishes after cancellation. Wait for the whole
    // obsolete task, including its completion callback, while the new request waits.
    service.completeRequest(0, with: signedIn("obsolete"))
    await obsoleteTask.value
    #expect(clerk.deviceToken == "new-token")
    #expect(clerk.client == nil)
    if stopBeforeCompletion { coordinator.stopAcceptingIdentityUpdates() }
    service.completeRequest(1, with: signedIn("replacement"))
    await replacementTask.value

    #expect(clerk.client?.id == (stopBeforeCompletion ? nil : "replacement"))
    #expect(replacementTask.isCancelled == stopBeforeCompletion)
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
    #expect(try WatchSyncClearMarker.generation(in: keychain) == 1)

    coordinator.apply(payload(token: "token", client: signedIn("client"), serverDate: .distantFuture), from: .phone, to: clerk)
    #expect(clerk.client == nil)

    coordinator.apply(payload(token: "new-token", client: signedIn("new"), serverDate: date(50), generation: 1), from: .phone, to: clerk)
    #expect(clerk.client?.id == "new")
  }

  @Test
  func unreadableClearGenerationFailsClosed() throws {
    // For example, a background launch before the first unlock after a reboot.
    let keychain = ReadFailingKeychain()
    try keychain.backing.set("4", forKey: ClerkKeychainKey.watchSyncClearGeneration.rawValue)

    #expect(throws: (any Error).self) { try WatchSyncClearMarker.record(in: keychain) }
    #expect(throws: (any Error).self) { try WatchSyncClearMarker.raise(to: 9, in: keychain) }
    #expect(try keychain.backing.string(forKey: ClerkKeychainKey.watchSyncClearGeneration.rawValue) == "4")
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
  func legacyClearImportPreservesTheOriginalDeviceScope() throws {
    let (clerk, keychain) = try makeClerk()
    try keychain.set(
      Data(#"{"device_token_state":"cleared","device_token_version":1726000000000,"auth_state":"cleared","auth_version":1726000000000}"#.utf8),
      forKey: ClerkKeychainKey.watchSyncMetadata.rawValue
    )
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    #if os(watchOS)
    #expect(try WatchSyncClearMarker.generation(in: keychain) == 0)
    // An old Watch-only clear must not reject or clear the phone's existing login.
    coordinator.apply(payload(token: "phone-token", client: signedIn("phone"), serverDate: date(100)), from: .phone, to: clerk)
    #expect(clerk.deviceToken == "phone-token")
    #else
    coordinator.apply(payload(token: "pre-clear-token", client: signedIn("old"), serverDate: .distantFuture), from: .watch, to: clerk)

    #expect(try WatchSyncClearMarker.generation(in: keychain) == 1)
    #expect(clerk.client == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
    #endif
  }

  @Test
  func existingClearGenerationIsPreservedDuringLegacyImport() throws {
    let (_, keychain) = try makeClerk()
    try keychain.set("4", forKey: ClerkKeychainKey.watchSyncClearGeneration.rawValue)
    try keychain.set("cleared", forKey: ClerkKeychainKey.watchSyncAuthState.rawValue)

    #expect(try WatchSyncClearMarker.generation(in: keychain) == 4)
    try WatchSyncClearMarker.record(in: keychain)
    #expect(try WatchSyncClearMarker.generation(in: keychain) == 5)
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
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      clientService: clientService ?? MockClientService(get: { throw CancellationError() })
    )
    try dependencies.configurationManager.configure(publishableKey: testPublishableKey, options: .init())
    clerk.dependencies = dependencies
    if token != nil {
      try clerk.seedIdentity(deviceToken: token, client: client, serverDate: serverDate)
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

@MainActor
private final class SuspendedWatchClientService: ClientServiceProtocol {
  private var requests: [Int: CheckedContinuation<ClientServiceResponse, any Error>] = [:]
  private(set) var calls = 0

  func getResponse(skipClientId _: Bool) async throws -> ClientServiceResponse {
    let index = calls
    calls += 1
    return try await withCheckedThrowingContinuation { requests[index] = $0 }
  }

  func completeRequest(_ index: Int, with client: Client) {
    requests.removeValue(forKey: index)?.resume(returning: ClientServiceResponse(client: client, requestSequence: nil, serverDate: nil))
  }

  func cancelPendingRequests() {
    let pending = requests.values
    requests.removeAll()
    for request in pending {
      request.resume(throwing: CancellationError())
    }
  }
}

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

/// A Keychain that cannot be read, as before the first unlock, but records writes in `backing`.
private final class ReadFailingKeychain: @unchecked Sendable, KeychainStorage {
  let backing = InMemoryKeychain()

  func set(_ data: Data, forKey key: String) throws {
    try backing.set(data, forKey: key)
  }

  func data(forKey _: String) throws -> Data? {
    throw KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey _: String) throws -> Bool {
    throw KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
  }
}
