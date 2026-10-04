@_spi(FrameworkIntegration) @testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct KeychainSharingTests {
  private let sharedKeychain = InMemoryKeychain()

  @Test
  func anotherAppsTokenIsUsedForTheNextRequest() async throws {
    let first = makeApp()
    let second = makeApp()

    try await first.respond(.client(signedIn("client")), token: .set("token"), date: 100)
    let request = try await second.clerk.identityController.captureRequestIdentity()

    #expect(request.deviceToken == "token")
    #expect(second.clerk.deviceToken == "token")
    #expect(second.clerk.client == nil)
  }

  @Test
  func launchUsesTheTokenAnotherAppStored() async throws {
    let first = makeApp()
    try await first.respond(.client(signedIn("client")), token: .set("token"), date: 100)

    let second = makeApp()

    #expect(second.clerk.deviceToken == "token")
    #expect(second.clerk.client == nil)
  }

  @Test
  func eachAppCachesItsOwnClient() async throws {
    let first = makeApp()
    let second = makeApp()
    try await first.respond(.client(signedIn("first")), token: .set("token"), date: 100)
    try await second.respond(.client(signedIn("second")), date: 200)

    #expect(try first.store.load()?.client?.id == "first")
    #expect(try second.store.load()?.client?.id == "second")
  }

  @Test
  func anotherAppsClearSignsThisAppOutOnForeground() async throws {
    let first = makeApp()
    let second = makeApp()
    try await first.respond(.client(signedIn("client")), token: .set("token"), date: 100)
    try await second.respond(.client(signedIn("client")), date: 100)

    try first.clerk.identityController.clearIdentity()
    await second.clerk.runtime.onWillEnterForeground()

    #expect(second.clerk.deviceToken == nil)
    #expect(second.clerk.client == nil)
  }

  @Test
  func responseForATokenAnotherAppReplacedIsIgnored() async throws {
    let first = makeApp()
    let second = makeApp()
    try await first.respond(.client(signedIn("old")), token: .set("old-token"), date: 100)
    let staleRequest = try await second.clerk.identityController.captureRequestIdentity()

    try await first.respond(.client(signedIn("new")), token: .set("new-token"), date: 200)
    try await second.respond(.client(signedIn("stale")), date: 300, request: staleRequest)

    #expect(second.clerk.deviceToken == "new-token")
    #expect(second.clerk.client == nil)
    #expect(try first.store.load()?.client?.id == "new")
  }

  @Test
  func watchUpdateReachesTheOtherApps() async throws {
    let first = makeApp()
    let second = makeApp()
    let watch = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())

    watch.apply(WatchSyncChange(deviceToken: "watch-token", changedAt: .now), to: first.clerk)
    _ = try await second.clerk.identityController.captureRequestIdentity()

    #expect(second.clerk.deviceToken == "watch-token")
  }

  @Test
  func clientChangeInOneAppRefreshesTheOthersWithoutEchoing() async throws {
    let name = "com.clerk.tests.shared-identity.\(UUID().uuidString)"
    let firstRefreshes = LockIsolated(0)
    let secondRefreshes = LockIsolated(0)
    let first = makeApp(refreshes: firstRefreshes)
    let second = makeApp(refreshes: secondRefreshes, refreshedClient: signedIn("renamed"))
    try await first.respond(.client(signedIn("client")), token: .set("token"), date: 100)
    let firstNotifier = SharedIdentityNotifier(name: name, clerk: first.clerk)
    let secondNotifier = SharedIdentityNotifier(name: name, clerk: second.clerk)
    first.clerk.runtime.internalStateChanges.addObserver(firstNotifier)
    second.clerk.runtime.internalStateChanges.addObserver(secondNotifier)
    defer {
      firstNotifier.stop()
      secondNotifier.stop()
    }

    first.clerk.applyResponseClient(signedIn("renamed"))
    for _ in 0 ..< 100 where second.clerk.client?.id != "renamed" {
      try await Task.sleep(for: .milliseconds(10))
    }
    try await Task.sleep(for: .milliseconds(200))

    #expect(secondRefreshes.value == 1)
    #expect(second.clerk.deviceToken == "token")
    #expect(second.clerk.client?.id == "renamed")
    #expect(firstRefreshes.value == 0)
  }

  @Test
  func tokenRefreshInOneAppDoesNotRefreshTheOthers() async throws {
    let name = "com.clerk.tests.shared-identity.\(UUID().uuidString)"
    let secondRefreshes = LockIsolated(0)
    let first = makeApp()
    let second = makeApp(refreshes: secondRefreshes)
    try await first.respond(.client(signedIn("client")), token: .set("token"), date: 100)
    let firstNotifier = SharedIdentityNotifier(name: name, clerk: first.clerk)
    let secondNotifier = SharedIdentityNotifier(name: name, clerk: second.clerk)
    first.clerk.runtime.internalStateChanges.addObserver(firstNotifier)
    second.clerk.runtime.internalStateChanges.addObserver(secondNotifier)
    defer {
      firstNotifier.stop()
      secondNotifier.stop()
    }
    let session = try #require(first.clerk.session)
    let now = Int(Date.now.timeIntervalSince1970)
    let refreshed = try TokenResource(jwt: testJWT(claims: ["sid": session.id, "iat": now, "exp": now + 60]))
    let controller = first.clerk.identityController

    let accepted = controller.updateSessionToken(refreshed, for: controller.makeSessionTokenRequest(for: session))
    try await Task.sleep(for: .milliseconds(200))

    #expect(accepted == refreshed)
    #expect(first.clerk.session?.lastActiveToken == refreshed)
    #expect(try first.store.load()?.client?.currentSession?.lastActiveToken == refreshed)
    #expect(secondRefreshes.value == 0)
  }

  @Test
  func appDoesNotRefreshForItsOwnChange() async throws {
    let name = "com.clerk.tests.shared-identity.\(UUID().uuidString)"
    let refreshes = LockIsolated(0)
    let app = makeApp(refreshes: refreshes)
    try await app.respond(.client(signedIn("client")), token: .set("token"), date: 100)
    let notifier = SharedIdentityNotifier(name: name, clerk: app.clerk)
    defer { notifier.stop() }

    try notifier.handle(.clientDidChange(previous: nil, current: signedIn("client")), from: app.clerk)
    try await Task.sleep(for: .milliseconds(200))

    #expect(refreshes.value == 0)
  }

  private func makeApp(refreshes: LockIsolated<Int>? = nil, refreshedClient: Client? = nil) -> App {
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      appLocalKeychain: InMemoryKeychain(),
      identityKeychain: sharedKeychain,
      clientKeychain: InMemoryKeychain(),
      identityIsInAccessGroup: true,
      clientService: MockClientService(get: {
        refreshes?.withValue { $0 += 1 }
        return refreshedClient
      })
    )
    clerk.identityController.hydrate()
    return App(clerk: clerk)
  }
}

@MainActor
private struct App {
  let clerk: Clerk

  var store: ClerkIdentityStore {
    clerk.dependencies.identityStore
  }

  func respond(
    _ update: ClientResponseUpdate,
    token: ClerkDeviceTokenResponseUpdate = .absent,
    date seconds: TimeInterval,
    request: ClerkIdentityRequestSnapshot? = nil
  ) async throws {
    let request = if let request { request } else { try await clerk.identityController.captureRequestIdentity() }
    try await clerk.identityController.applyNetworkResponse(ClientSyncResponseContext(
      update: update,
      deviceTokenUpdate: token,
      requestDeviceToken: request.deviceToken,
      serverDate: Date(timeIntervalSince1970: seconds),
      isCanonicalClientRequest: true,
      clientResponseGeneration: request.clientResponseGeneration,
      responseSequence: 1
    ))
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
