@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Testing

@MainActor
final class RecordingWatchSyncTransport: WatchSyncTransport {
  private(set) var sent: [WatchSyncChange] = []

  func send(_ change: WatchSyncChange) {
    sent.append(change)
  }
}

struct WatchSyncChangeTests {
  @Test
  func roundTripsThroughTheApplicationContext() {
    let signedIn = WatchSyncChange(deviceToken: "token", clientId: "client", changedAt: date(100))
    let signedOut = WatchSyncChange(deviceToken: nil, changedAt: date(200))

    #expect(WatchSyncChange(applicationContext: signedIn.applicationContext) == signedIn)
    #expect(WatchSyncChange(applicationContext: signedOut.applicationContext) == signedOut)
  }

  @Test
  func contextWithoutAChangeTimeCarriesNoChange() {
    #expect(WatchSyncChange(applicationContext: ["clerkWatchSyncDeviceToken": "token"]) == nil)
  }
}

@MainActor
@Suite(.serialized)
struct WatchConnectivityCoordinatorTests {
  @Test
  func signingInSendsTheToken() throws {
    let (clerk, _) = try makeClerk(token: "token", client: signedIn("client"))
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)

    try coordinator.handle(.identityDidChange, from: clerk)

    #expect(transport.sent.map(\.deviceToken) == ["token"])
  }

  @Test
  func anonymousTokensAreNotSent() throws {
    let (clerk, _) = try makeClerk(token: "anonymous", client: signedOut("client"))
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)

    try coordinator.handle(.identityDidChange, from: clerk)

    #expect(transport.sent.isEmpty)
  }

  @Test
  func nothingIsSentWhileTheClientIsUnknown() throws {
    let (clerk, _) = try makeClerk(token: "token")
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)

    try coordinator.handle(.identityDidChange, from: clerk)

    #expect(transport.sent.isEmpty)
  }

  @Test
  func signingOutSendsTheSignOut() throws {
    let (clerk, _) = try makeClerk(token: "token", client: signedIn("client"))
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    try coordinator.handle(.identityDidChange, from: clerk)

    clerk.applyResponseClient(signedOut("client"))
    try coordinator.handle(.identityDidChange, from: clerk)

    #expect(transport.sent.map(\.deviceToken) == ["token", nil])
  }

  @Test
  func signingOutSendsTheSignOutWhenTheTokenRotates() throws {
    let (clerk, _) = try makeClerk(token: "token", client: signedIn("client"))
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    try coordinator.handle(.identityDidChange, from: clerk)

    try clerk.identityController.adoptDeviceToken("rotated-token")
    clerk.applyResponseClient(signedOut("client"))
    try coordinator.handle(.identityDidChange, from: clerk)

    #expect(transport.sent.map(\.deviceToken) == ["token", nil])
  }

  @Test
  func staleTokenDoesNotSignOutThePairedDevice() throws {
    let (clerk, _) = try makeClerk(token: "token", client: signedIn("client"))
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    try coordinator.handle(.identityDidChange, from: clerk)

    try clerk.identityController.adoptDeviceToken("new-client-token")
    clerk.applyResponseClient(signedOut("new-client"))
    try coordinator.handle(.identityDidChange, from: clerk)
    coordinator.apply(WatchSyncChange(deviceToken: "rotated-token", clientId: "client", changedAt: .now), to: clerk)

    #expect(transport.sent.map(\.deviceToken) == ["token"])
    #expect(clerk.deviceToken == "rotated-token")
  }

  @Test
  func clientChangeWhileSignedInIsSent() throws {
    let client = signedIn("client")
    let (clerk, _) = try makeClerk(token: "token", client: client)
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    try coordinator.handle(.identityDidChange, from: clerk)
    var renamed = client
    renamed.updatedAt = .now

    try coordinator.handle(.clientDidChange(previous: client, current: client), from: clerk)
    try coordinator.handle(.clientDidChange(previous: client, current: renamed), from: clerk)

    #expect(transport.sent.map(\.deviceToken) == ["token", "token"])
    #expect(transport.sent[1].changedAt > transport.sent[0].changedAt)
  }

  @Test
  func sessionTokenRefreshIsNotSent() throws {
    let client = signedIn("client")
    let (clerk, _) = try makeClerk(token: "token", client: client)
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    try coordinator.handle(.identityDidChange, from: clerk)
    var refreshed = client
    refreshed.sessions[0].lastActiveToken = TokenResource(jwt: "refreshed.jwt")

    try coordinator.handle(.clientDidChange(previous: client, current: refreshed), from: clerk)

    #expect(transport.sent.map(\.deviceToken) == ["token"])
  }

  @Test
  func clientRefreshedForThePairedDeviceIsNotSentBack() throws {
    let client = signedIn("client")
    let (clerk, _) = try makeClerk(token: "token", client: client)
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    var refreshed = client
    refreshed.updatedAt = .now

    coordinator.apply(WatchSyncChange(deviceToken: "token", clientId: "client", changedAt: .now), to: clerk)
    try coordinator.handle(.clientDidChange(previous: client, current: refreshed), from: clerk)

    #expect(transport.sent.isEmpty)
  }

  @Test
  func newerSignInFromThePairedDeviceIsAdopted() throws {
    let (clerk, _) = try makeClerk()
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    coordinator.apply(WatchSyncChange(deviceToken: "paired-token", changedAt: .now), to: clerk)

    #expect(clerk.deviceToken == "paired-token")
    #expect(clerk.client == nil)
  }

  @Test
  func pairedSignOutSignsOutThisDevice() throws {
    let (clerk, _) = try makeClerk(token: "token", client: signedIn("client"))
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    coordinator.apply(WatchSyncChange(deviceToken: nil, changedAt: .now), to: clerk)

    #expect(clerk.deviceToken == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func olderChangeFromThePairedDeviceIsIgnored() throws {
    let (clerk, _) = try makeClerk(token: "token", client: signedIn("client"))
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    try coordinator.handle(.identityDidChange, from: clerk)

    coordinator.apply(WatchSyncChange(deviceToken: nil, changedAt: .distantPast), to: clerk)

    #expect(clerk.deviceToken == "token")
  }

  @Test
  func adoptedChangeIsNotSentBack() throws {
    let (clerk, _) = try makeClerk(token: "token", client: signedIn("client"))
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)

    coordinator.apply(WatchSyncChange(deviceToken: nil, changedAt: .now), to: clerk)
    try coordinator.handle(.identityDidChange, from: clerk)

    #expect(transport.sent.isEmpty)
  }

  @Test
  func clearIsSentAndAnOlderSignInCannotUndoIt() throws {
    let (clerk, _) = try makeClerk(token: "token", client: signedIn("client"))
    let transport = RecordingWatchSyncTransport()
    let coordinator = WatchConnectivityCoordinator(transport: transport)
    try coordinator.handle(.identityDidChange, from: clerk)
    let signIn = try #require(transport.sent.last)

    try clerk.identityController.clearIdentity()
    try coordinator.handle(.localStorageDidClear, from: clerk)
    Clerk.clearAllKeychainItems(in: clerk.dependencies.keychain)
    coordinator.apply(signIn, to: clerk)

    #expect(transport.sent.last?.deviceToken == nil)
    #expect(clerk.deviceToken == nil)
  }

  @Test
  func changeThatFailsToApplyIsNotRecorded() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: FakeTransport.answeringClient { throw CancellationError() },
      keychain: keychain,
      identityKeychain: SetFailingKeychain()
    )
    try dependencies.configurationManager.configure(publishableKey: testPublishableKey, options: .init())
    clerk.dependencies = dependencies
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    coordinator.apply(WatchSyncChange(deviceToken: "paired-token", changedAt: .now), to: clerk)

    #expect(clerk.deviceToken == nil)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.watchSyncLastChange.rawValue) == false)
  }

  private func makeClerk(
    token: String? = nil,
    client: Client? = nil
  ) throws -> (Clerk, InMemoryKeychain) {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: FakeTransport.answeringClient { throw CancellationError() },
      keychain: keychain
    )
    try dependencies.configurationManager.configure(publishableKey: testPublishableKey, options: .init())
    clerk.dependencies = dependencies
    try clerk.seedIdentity(deviceToken: token, client: client)
    return (clerk, keychain)
  }
}

private func date(_ seconds: TimeInterval) -> Date {
  Date(timeIntervalSince1970: seconds)
}

private func signedIn(_ id: String) -> Client {
  var client = Client.mock
  client.id = id
  return client
}

private func signedOut(_ id: String) -> Client {
  var client = Client.mockSignedOut
  client.id = id
  return client
}
