//
//  SharedSessionSyncTests.swift
//  Clerk
//

@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Testing

/// Two in-process "apps" that share one identity record, with a hub standing in for Darwin notifications.
@MainActor
@Suite(.serialized)
struct SharedSessionSyncTests {
  @Test
  func siblingSignInAndSignOutReachTheOtherApp() async throws {
    let hub = NotificationHub()
    let first = makeApp(hub: hub)
    let second = makeApp(hub: hub)

    try await first.respond(.client(signedIn("client")), token: .set("token"), date: 100)
    #expect(second.clerk.deviceToken == "token")
    #expect(second.clerk.client?.id == "client")

    try await second.respond(.client(signedOut("client")), date: 200)
    #expect(first.clerk.client?.sessions.isEmpty == true)
    #expect(first.clerk.lastClientServerFetchDate == date(200))
  }

  @Test
  func coldStartLoadsTheIdentityAnotherAppWrote() async throws {
    let hub = NotificationHub()
    let first = makeApp(hub: hub)
    try await first.respond(.client(signedIn("client")), token: .set("token"), date: 100)

    let second = makeApp(hub: hub, keychain: first.keychain)

    #expect(second.clerk.deviceToken == "token")
    #expect(second.clerk.client?.id == "client")
  }

  @Test
  func missedNotificationIsRecoveredOnForegroundAndBeforeRequests() async throws {
    let hub = NotificationHub()
    let first = makeApp(hub: hub)
    let second = makeApp(hub: hub)
    hub.isDelivering = false

    try await first.respond(.client(signedIn("client")), token: .set("token"), date: 100)
    #expect(second.clerk.deviceToken == nil)

    let request = try await second.clerk.identityController.captureRequestIdentity()
    #expect(request.deviceToken == "token")
    #expect(second.clerk.client?.id == "client")

    try await first.respond(.client(signedOut("client")), date: 200)
    await second.clerk.onWillEnterForeground()
    #expect(second.clerk.client?.sessions.isEmpty == true)
  }

  @Test
  func responseForATokenAnotherAppReplacedIsRejected() async throws {
    let hub = NotificationHub()
    let first = makeApp(hub: hub)
    let second = makeApp(hub: hub)
    try await first.respond(.client(signedIn("old")), token: .set("old-token"), date: 100)
    let staleRequest = try await second.clerk.identityController.captureRequestIdentity()

    try await first.respond(.client(signedIn("new")), token: .set("new-token"), date: 200)
    try await second.clerk.identityController.applyNetworkResponse(ClientSyncResponseContext(
      update: .client(signedIn("stale")),
      deviceTokenUpdate: .absent,
      requestDeviceToken: staleRequest.deviceToken,
      serverDate: date(300),
      isCanonicalClientRequest: true,
      clientResponseGeneration: staleRequest.clientResponseGeneration,
      responseSequence: 9
    ))

    #expect(second.clerk.deviceToken == "new-token")
    #expect(second.clerk.client?.id == "new")
    #expect(try first.store.load()?.identity.client?.id == "new")
  }

  @Test
  func olderResponseCannotReplaceANewerSnapshotFromAnotherApp() async throws {
    let hub = NotificationHub()
    let first = makeApp(hub: hub)
    let second = makeApp(hub: hub)
    try await first.respond(.client(signedIn("client")), token: .set("token"), date: 100)
    let request = try await second.clerk.identityController.captureRequestIdentity()

    try await first.respond(.client(signedOut("client")), date: 300)
    try await second.respond(.client(signedIn("client")), date: 200, request: request)

    #expect(second.clerk.client?.sessions.isEmpty == true)
    #expect(try first.store.load()?.identity.serverDate == date(300))

    try await second.respond(.client(signedIn("client")), date: 400, request: request, sequence: 2)
    #expect(first.clerk.client?.sessions.isEmpty == false)
  }

  @Test
  func clearSignsOutEveryApp() async throws {
    let hub = NotificationHub()
    let first = makeApp(hub: hub)
    let second = makeApp(hub: hub)
    try await first.respond(.client(signedIn("client")), token: .set("token"), date: 100)

    try second.clerk.identityController.clearIdentity()

    #expect(first.clerk.deviceToken == nil)
    #expect(first.clerk.client == nil)
    #expect(try first.store.load() == nil)
  }

  @Test
  func onlyWritesNotifyTheOtherApps() async throws {
    let hub = NotificationHub()
    let first = makeApp(hub: hub)
    let second = makeApp(hub: hub)

    try await first.respond(.client(signedIn("client")), token: .set("token"), date: 100)
    #expect(hub.postCount == 1)

    _ = try await second.clerk.identityController.captureRequestIdentity()
    #expect(await !second.clerk.reloadFromSharedStorage())
    #expect(hub.postCount == 1)
  }

  @Test
  func watchUpdateIsSharedWithTheOtherApps() {
    let hub = NotificationHub()
    let first = makeApp(hub: hub)
    let second = makeApp(hub: hub)
    let watch = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    watch.apply(
      WatchSyncPayload(
        state: WatchSyncState(deviceToken: "watch-token", client: signedIn("watch"), serverDate: date(100)),
        environment: nil
      ),
      from: .phone,
      to: first.clerk
    )

    #expect(second.clerk.deviceToken == "watch-token")
    #expect(second.clerk.client?.id == "watch")
  }

  @Test
  func updateDeviceTokenIsSharedWithTheOtherApps() async throws {
    let hub = NotificationHub()
    let first = makeApp(hub: hub)
    let second = makeApp(hub: hub)
    try await first.respond(.client(signedIn("client")), token: .set("old-token"), date: 100)

    _ = try await second.clerk.identityController.updateDeviceToken(to: "new-token")

    #expect(first.clerk.deviceToken == "new-token")
    #expect(first.clerk.client == nil)
  }

  @Test
  func notificationNameDoesNotExposeKeychainConfiguration() throws {
    let config = Clerk.Options.KeychainConfig(
      service: "com.example.clerk",
      accessGroup: "TEAMID.com.example.clerk"
    )
    let name = SharedSessionSyncDarwinNotifier.notificationName(for: config)

    #expect(!name.contains(config.service))
    #expect(try !name.contains(#require(config.accessGroup)))
    #expect(name != SharedSessionSyncDarwinNotifier.notificationName(for: config, instanceFingerprint: "another-instance"))
    #expect(name == SharedSessionSyncDarwinNotifier.notificationName(
      for: .init(service: config.service, accessGroup: "  TEAMID.com.example.clerk\n")
    ))
  }

  // MARK: - Helpers

  private func makeApp(hub: NotificationHub, keychain: InMemoryKeychain? = nil) -> App {
    let keychain = keychain ?? hub.keychain
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      appLocalKeychain: InMemoryKeychain(),
      identityKeychain: keychain,
      sharesIdentity: true
    )
    clerk.identityController.hydrate()
    clerk.identityController.startSharing(notifier: hub.makeNotifier())
    return App(clerk: clerk, keychain: keychain)
  }
}

@MainActor
private struct App {
  let clerk: Clerk
  let keychain: InMemoryKeychain

  var store: ClerkIdentityStore {
    clerk.dependencies.identityStore
  }

  func respond(
    _ update: ClientResponseUpdate,
    token: ClerkDeviceTokenResponseUpdate = .absent,
    date seconds: TimeInterval,
    request: ClerkIdentityRequestSnapshot? = nil,
    sequence: Int = 1
  ) async throws {
    let request = if let request { request } else { try await clerk.identityController.captureRequestIdentity() }
    try await clerk.identityController.applyNetworkResponse(ClientSyncResponseContext(
      update: update,
      deviceTokenUpdate: token,
      requestDeviceToken: request.deviceToken,
      serverDate: Date(timeIntervalSince1970: seconds),
      isCanonicalClientRequest: true,
      clientResponseGeneration: request.clientResponseGeneration,
      responseSequence: sequence
    ))
  }
}

/// Delivers each post synchronously to every other notifier, like a Darwin notification.
@MainActor
private final class NotificationHub {
  /// The access-group Keychain every app in the test shares.
  let keychain = InMemoryKeychain()
  private var notifiers: [HubNotifier] = []
  private(set) var postCount = 0
  var isDelivering = true

  func makeNotifier() -> HubNotifier {
    let notifier = HubNotifier(hub: self)
    notifiers.append(notifier)
    return notifier
  }

  fileprivate func post(from sender: HubNotifier) {
    postCount += 1
    guard isDelivering else { return }
    for notifier in notifiers where notifier !== sender {
      notifier.handler()
    }
  }
}

@MainActor
private final class HubNotifier: SharedSessionSyncNotifying {
  private weak var hub: NotificationHub?
  fileprivate var handler: @MainActor () -> Void = {}

  init(hub: NotificationHub) {
    self.hub = hub
  }

  func setHandler(_ handler: @escaping @MainActor () -> Void) {
    self.handler = handler
  }

  func post() {
    hub?.post(from: self)
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
