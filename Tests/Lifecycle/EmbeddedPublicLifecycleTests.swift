#if !os(watchOS)
import ClerkJSCore
@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct EmbeddedPublicLifecycleTests {
  @Test
  func restoresLegacyIdentityBeforeLoadingAndCoalescesStartup() async throws {
    let fixture = try LifecycleFixture()
    let clerk = try await fixture.configure()
    #expect(clerk.isLoaded)
    #expect(clerk.session?.id == "sess_fixture")
    #expect(clerk.user?.id == "user_fixture")
    try await fixture.initialize()
    #expect(fixture.requests.filter { $0 == "/v1/client" }.count == 1)
    #expect(fixture.requests.filter { $0 == "/v1/environment" }.count == 1)
    #expect(fixture.credentials.allSatisfy { $0 == "restored-device-token" })
    await fixture.dispose()
  }

  @Test
  func publicTokenCallsShareRefreshAndEmitAfterObservedState() async throws {
    let fixture = try LifecycleFixture()
    let clerk = try await fixture.configure()
    try await fixture.initialize()
    let retained = try #require(clerk.session)
    let events = clerk.auth.events
    let tokenEvents = LockIsolated<[(String, String?)]>([])
    let observed = Task { @MainActor in
      for await event in events {
        if case .tokenRefreshed(let jwt) = event {
          let snapshot = clerk.session?.lastActiveToken.jwt
          tokenEvents.withValue { $0.append((jwt, snapshot)) }
        }
      }
    }
    defer { observed.cancel() }
    async let first = clerk.auth.getToken()
    async let second = retained.getToken()
    let (one, two) = try await (first, second)
    #expect(one == two)
    #expect(fixture.mints == 1)
    for _ in 0 ..< 20 {
      await Task.yield()
    }
    #expect(tokenEvents.value.last?.0 == one)
    #expect(tokenEvents.value.last?.1 == one)
    _ = try await retained.getToken(.init(skipCache: true))
    #expect(fixture.mints == 2)
    await fixture.dispose()
  }

  @Test
  func offlineRestorationRecoversThroughForeground() async throws {
    let fixture = try LifecycleFixture()
    fixture.offline = true
    let clerk = try await fixture.configure()
    try await fixture.initialize()
    #expect(clerk.session?.id == "sess_fixture")
    #expect(clerk.isLoaded)
    await clerk.onDidEnterBackground()
    let host = try #require(fixture.host)
    _ = try await host.runtime.evaluateJSON("(() => { globalThis.originalTimer = setTimeout; globalThis.setTimeout = (f, ms) => originalTimer(f, Math.min(ms, 1)); return true; })()")
    await #expect(throws: Error.self) { try await clerk.auth.getToken() }
    _ = try await host.runtime.evaluateJSON("(globalThis.setTimeout = originalTimer, true)")
    #expect(clerk.session?.id == "sess_fixture")
    fixture.offline = false
    await clerk.onWillEnterForeground()
    #expect(try await clerk.auth.getToken()?.isEmpty == false)
    #expect(fixture.mints == 1)
    await fixture.dispose()
  }

  @Test
  func signOutPersistsAcrossRestartAndInvalidatesRetainedSession() async throws {
    let fixture = try LifecycleFixture()
    let clerk = try await fixture.configure()
    try await fixture.initialize()
    let retained = try #require(clerk.session)
    try await clerk.auth.signOut()
    #expect(clerk.session == nil)
    #expect(clerk.user == nil)
    await #expect(throws: Error.self) { try await retained.getToken() }
    await fixture.dispose()
    let restored = try await fixture.configure()
    #expect(restored.session == nil)
    try await fixture.initialize()
    #expect(restored.session == nil)
    await fixture.dispose()
  }

  @Test
  func backgroundStopsScheduledRefreshAndForegroundFindsRevokedSession() async throws {
    let fixture = try LifecycleFixture()
    let clerk = try await fixture.configure()
    try await fixture.initialize()
    await clerk.onDidEnterBackground()
    let host = try #require(fixture.host)
    _ = try await host.runtime.evaluateJSON("(() => { globalThis.originalTimer = setTimeout; globalThis.setTimeout = (f, ms) => originalTimer(f, ms === 5000 ? 10 : ms); return true; })()")
    await clerk.onWillEnterForeground()
    await clerk.onDidEnterBackground()
    let count = fixture.requests.count
    try await Task.sleep(for: .milliseconds(100))
    #expect(fixture.requests.count == count)
    fixture.revoke()
    await clerk.onWillEnterForeground()
    #expect(clerk.session == nil)
    #expect(clerk.user == nil)
    await fixture.dispose()
  }

  @Test
  func keychainClearDisposesRuntimeAndDoesNotRestoreCachedIdentity() async throws {
    let fixture = try LifecycleFixture()
    let clerk = try await fixture.configure()
    try await fixture.initialize()
    let host = try #require(fixture.host)
    try await Clerk.clearAllKeychainItemsAndWait()
    #expect(clerk.session?.id == "sess_fixture")
    #expect(try fixture.keychain.data(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
    await #expect(throws: Error.self) { try await host.invoke(.init(receiver: .clerk, method: "refreshClient", arguments: [])) }
    await fixture.dispose()
    fixture.offline = true
    let restored = try await fixture.configure()
    #expect(restored.session == nil)
    await fixture.dispose()
  }

  @Test
  func cancellingOneCallerKeepsSharedTokenRequestAlive() async throws {
    let fixture = try LifecycleFixture()
    let clerk = try await fixture.configure()
    try await fixture.initialize()
    fixture.holdTokens()
    let first = Task { try await clerk.auth.getToken() }
    try await fixture.waitForHeldToken()
    let second = Task { try await clerk.auth.getToken() }
    for _ in 0 ..< 20 {
      await Task.yield()
    }
    first.cancel()
    await #expect(throws: Error.self) { try await first.value }
    fixture.releaseTokens()
    #expect(try await second.value?.isEmpty == false)
    #expect(fixture.mints == 1)
    #expect(clerk.session?.id == "sess_fixture")
    await fixture.dispose()
  }

  @Test(arguments: [false, true])
  func pendingTokenCannotRestoreIdentityAfterClearOrReconfiguration(reconfigure: Bool) async throws {
    let fixture = try LifecycleFixture()
    let clerk = try await fixture.configure()
    try await fixture.initialize()
    fixture.holdTokens()
    let pending = Task { try await clerk.auth.getToken() }
    try await fixture.waitForHeldToken()
    fixture.revoke()
    if reconfigure {
      _ = try await Clerk.reconfigure(
        publishableKey: testPublishableKey,
        options: .init(keychainConfig: .init(service: "clerk-lifecycle-test-" + UUID().uuidString))
      )
      try await fixture.initialize()
      #expect(Clerk.shared.session == nil)
    } else {
      try await Clerk.clearAllKeychainItemsAndWait()
    }
    fixture.releaseTokens()
    await #expect(throws: Error.self) { try await pending.value }
    if reconfigure {
      #expect(Clerk.shared.session == nil)
      try await Clerk.clearAllKeychainItemsAndWait()
    }
    #expect(try fixture.keychain.data(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
    await fixture.dispose()
  }
}

@MainActor
private final class LifecycleFixture {
  let keychain = InMemoryKeychain()
  var host: ClerkJSHost?
  private let state: LockIsolated<TransportState>

  private struct TransportState: @unchecked Sendable {
    var client: [String: Any]
    var environment: Any
    var offline = false
    var requests: [String] = []
    var credentials: [String] = []
    var mints = 0
    var holdTokens = false
    var releases: [@Sendable () -> Void] = []
  }

  init() throws {
    var client = try JSONSerialization.jsonObject(with: ClerkJSHost.snapshotSignedInClient()) as! [String: Any]
    var sessions = client["sessions"] as! [[String: Any]]
    sessions[0]["expire_at"] = Date().addingTimeInterval(3600).timeIntervalSince1970.rounded(.down) * 1000
    sessions[0]["abandon_at"] = Date().addingTimeInterval(86400).timeIntervalSince1970.rounded(.down) * 1000
    sessions[0]["last_active_token"] = ["object": "token", "jwt": Self.jwt(expiry: -60, count: 0)]
    client["sessions"] = sessions
    let environment = try ClerkJSHost.snapshotEnvironmentJSON()
    let initialState = try TransportState(client: client, environment: JSONSerialization.jsonObject(with: environment))
    state = .init(initialState)
    let model = try JSONDecoder.clerkDecoder.decode(Client.self, from: JSONSerialization.data(withJSONObject: client))
    try keychain.set(JSONEncoder.clerkEncoder.encode(model), forKey: ClerkKeychainKey.cachedClient.rawValue)
    try keychain.set(environment, forKey: ClerkKeychainKey.cachedEnvironment.rawValue)
    try keychain.set(Data("restored-device-token".utf8), forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
  }

  var requests: [String] {
    state.value.requests
  }

  var credentials: [String] {
    state.value.credentials
  }

  var mints: Int {
    state.value.mints
  }

  var offline: Bool {
    get { state.value.offline }
    set { state.withValue { $0.offline = newValue } }
  }

  func revoke() {
    state.withValue { value in
      value.client["sessions"] = []
      value.client["last_active_session_id"] = NSNull()
    }
  }

  func holdTokens() {
    state.withValue { $0.holdTokens = true }
  }

  func waitForHeldToken() async throws {
    for _ in 0 ..< 5000 {
      if state.withValue({ !$0.releases.isEmpty }) { return }
      try await Task.sleep(for: .milliseconds(1))
    }
    throw URLError(.timedOut)
  }

  func releaseTokens() {
    let releases = state.withValue { value in
      value.holdTokens = false
      let releases = value.releases
      value.releases = []
      return releases
    }
    releases.forEach { $0() }
  }

  func configure() async throws -> Clerk {
    await Clerk.resetSharedInstanceForTesting()
    let state = state
    LifecycleURLProtocol.gate.setValue { request, release in
      state.withValue { value in
        guard value.holdTokens, request.url?.path.hasSuffix("/tokens") == true else { return false }
        value.releases.append(release)
        return true
      }
    }
    LifecycleURLProtocol.handler.setValue { request in
      try state.withValue { value in
        let path = request.url!.path
        value.requests.append(path)
        value.credentials.append(request.value(forHTTPHeaderField: "Authorization") ?? "")
        if value.offline { throw URLError(.notConnectedToInternet) }
        let response: Any
        switch path {
        case "/v1/environment": response = value.environment
        case "/v1/client": response = value.client
        case "/v1/client/sessions/sess_fixture/touch": response = (value.client["sessions"] as! [[String: Any]])[0]
        case "/v1/client/sessions/sess_fixture/tokens":
          value.mints += 1
          return try JSONSerialization.data(withJSONObject: ["object": "token", "jwt": Self.jwt(expiry: 60, count: value.mints)])
        case "/v1/client/sessions/sess_fixture/remove", "/v1/client/sign_out", "/v1/client/sessions":
          value.client["sessions"] = []
          value.client["last_active_session_id"] = NSNull()
          response = value.client
        default: throw URLError(.unsupportedURL)
        }
        return try JSONSerialization.data(withJSONObject: ["response": response])
      }
    }
    Clerk.makeEngineClient = { [weak self] kit in
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [LifecycleURLProtocol.self]
      let host = ClerkJSHostStore.makeHost(for: kit, sessionConfiguration: config)
      self?.host = host
      return ClerkJSHostEngine(host: host, kit: kit)
    }
    return try Clerk.configureForTesting(publishableKey: testPublishableKey, options: .init(watchConnectivityEnabled: false), keychainStorage: keychain)
  }

  func initialize() async throws {
    _ = try await Clerk.requireEngineClient().invoke(.init(receiver: .clerk, method: "initialize", arguments: []))
  }

  func dispose() async {
    await Clerk.resetSharedInstanceForTesting()
    host = nil
  }

  private nonisolated static func jwt(expiry: Double, count: Int) -> String {
    let now = Int(Date().timeIntervalSince1970)
    let payload = try! JSONSerialization.data(withJSONObject: ["sub": "user_fixture", "sid": "sess_fixture", "iat": now + count, "exp": now + Int(expiry) + count])
    return "eyJhbGciOiJSUzI1NiJ9." + payload.base64EncodedString().replacingOccurrences(of: "=", with: "") + ".signature"
  }
}

private final class LifecycleURLProtocol: URLProtocol, @unchecked Sendable {
  private let stopped = LockIsolated(false)
  static let gate = LockIsolated<(@Sendable (URLRequest, @escaping @Sendable () -> Void) -> Bool)?>(nil)
  static let handler = LockIsolated<(@Sendable (URLRequest) throws -> Data)?>(nil)
  override class func canInit(with _: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    do {
      let data = try Self.handler.value!(request)
      let completion: @Sendable () -> Void = { [self] in
        guard !stopped.value else { return }
        var headers = ["Content-Type": "application/json"]
        if request.value(forHTTPHeaderField: "Authorization") == nil { headers["Authorization"] = "fresh-device-token" }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
      }
      if Self.gate.value?(request, completion) != true { completion() }
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {
    stopped.setValue(true)
  }
}
#endif
