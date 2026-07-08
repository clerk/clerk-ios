@testable import ClerkKit
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct SharedSessionSyncTests {
  @Test
  func publicReloadAppliesNewerSharedClientSnapshot() async throws {
    let keychain = InMemoryKeychain()
    let clerk = makeIsolatedClerk(keychain: keychain)
    let localClient = client(id: "client-local", signInId: "sign-in-local", updatedAt: 1000)
    let sharedClient = client(id: "client-shared", signInId: "sign-in-shared", updatedAt: 2000)

    clerk.applyResponseClient(localClient, responseSequence: 1, serverDate: Date(timeIntervalSince1970: 100))
    try persistSharedClient(
      sharedClient,
      state: .set,
      serverFetchDate: Date(timeIntervalSince1970: 200),
      version: 1,
      keychain: keychain
    )

    let changed = await clerk.reloadFromSharedStorage()

    #expect(changed)
    #expect(clerk.client?.id == sharedClient.id)
    #expect(clerk.client?.signIn?.id == sharedClient.signIn?.id)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
  }

  @Test
  func publicReloadAppliesNewerSharedClear() async throws {
    let keychain = InMemoryKeychain()
    let clerk = makeIsolatedClerk(keychain: keychain)

    clerk.applyResponseClient(
      client(id: "client-local", signInId: "sign-in-local", updatedAt: 1000),
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try persistSharedClient(nil, state: .cleared, serverFetchDate: Date(timeIntervalSince1970: 200), version: 1, keychain: keychain)

    let changed = await clerk.reloadFromSharedStorage()

    #expect(changed)
    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
  }

  @Test
  func notificationReloadDoesNotRollBackNewerLocalClient() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)
    let localClient = client(id: "client-local", signInId: "sign-in-local", updatedAt: 3000)
    let staleSharedClient = client(id: "client-shared", signInId: "sign-in-shared", updatedAt: 4000)

    clerk.applyResponseClient(localClient, responseSequence: 1, serverDate: Date(timeIntervalSince1970: 200))
    let initialPostCount = notifier.postCount
    try persistSharedClient(
      staleSharedClient,
      state: .set,
      serverFetchDate: Date(timeIntervalSince1970: 100),
      version: 1,
      keychain: keychain
    )

    notifier.simulateNotification()

    #expect(clerk.client?.id == localClient.id)
    #expect(clerk.client?.signIn?.id == localClient.signIn?.id)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
    #expect(notifier.postCount == initialPostCount + 1)

    let repairedClientData = try #require(try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue))
    let repairedClient = try JSONDecoder.clerkDecoder.decode(Client.self, from: repairedClientData)
    #expect(repairedClient.id == localClient.id)
    #expect(try loadClientServerFetchDate(from: keychain) == Date(timeIntervalSince1970: 200))
    #expect(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthState.rawValue) == SharedSessionSyncState.set.rawValue)
    let repairedRevision = try #require(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue))
    #expect(UUID(uuidString: repairedRevision) != nil)
  }

  @Test
  func notificationReloadDoesNotRollBackEqualDateSharedClientWithOlderUpdatedAt() throws {
    try assertEqualDateSharedClientDoesNotReplaceLocalClient(sharedUpdatedAt: 2000)
  }

  @Test
  func notificationReloadDoesNotRollBackEqualDateSharedClientWithEqualUpdatedAt() throws {
    try assertEqualDateSharedClientDoesNotReplaceLocalClient(sharedUpdatedAt: 3000)
  }

  @Test
  func notificationReloadRepairsStaleSharedClear() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)
    let localClient = client(id: "client-local", signInId: "sign-in-local", updatedAt: 3000)

    clerk.applyResponseClient(localClient, responseSequence: 1, serverDate: Date(timeIntervalSince1970: 200))
    let initialPostCount = notifier.postCount
    try persistSharedClient(
      nil,
      state: .cleared,
      serverFetchDate: Date(timeIntervalSince1970: 100),
      version: 1,
      keychain: keychain
    )

    notifier.simulateNotification()

    #expect(clerk.client?.id == localClient.id)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
    #expect(notifier.postCount == initialPostCount + 1)

    let repairedClientData = try #require(try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue))
    let repairedClient = try JSONDecoder.clerkDecoder.decode(Client.self, from: repairedClientData)
    #expect(repairedClient.id == localClient.id)
    #expect(try loadClientServerFetchDate(from: keychain) == Date(timeIntervalSince1970: 200))
    #expect(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthState.rawValue) == SharedSessionSyncState.set.rawValue)
    let repairedRevision = try #require(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue))
    #expect(UUID(uuidString: repairedRevision) != nil)
  }

  @Test
  func notificationReloadDoesNotResurrectOlderSharedClientOverLocalClear() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)
    let localClient = client(id: "client-local", signInId: "sign-in-local", updatedAt: 1000)
    let staleSharedClient = client(id: "client-shared", signInId: "sign-in-shared", updatedAt: 3000)

    clerk.applyResponseClient(localClient, responseSequence: 1, serverDate: Date(timeIntervalSince1970: 100))
    clerk.applyResponseClient(nil, responseSequence: 2, serverDate: Date(timeIntervalSince1970: 200))
    let initialPostCount = notifier.postCount
    try persistSharedClient(
      staleSharedClient,
      state: .set,
      serverFetchDate: Date(timeIntervalSince1970: 100),
      version: 1,
      keychain: keychain
    )

    notifier.simulateNotification()

    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
    #expect(notifier.postCount == initialPostCount + 1)
    #expect(try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue) == nil)
    #expect(try loadClientServerFetchDate(from: keychain) == Date(timeIntervalSince1970: 200))
    #expect(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthState.rawValue) == SharedSessionSyncState.cleared.rawValue)
    let repairedRevision = try #require(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue))
    #expect(UUID(uuidString: repairedRevision) != nil)
  }

  @Test
  func notificationReloadSuppressesEchoedPublish() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)
    let sharedClient = client(id: "client-shared", signInId: "sign-in-shared", updatedAt: 2000)

    try persistSharedClient(
      sharedClient,
      state: .set,
      serverFetchDate: Date(timeIntervalSince1970: 200),
      version: 1,
      keychain: keychain
    )

    notifier.simulateNotification()

    #expect(clerk.client?.id == sharedClient.id)
    #expect(notifier.postCount == 0)
  }

  @Test
  func notificationReloadFencesDeviceTokenOnlyChange() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)
    let initialGeneration = clerk.clientResponseGeneration

    try keychain.set("shared-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set(SharedSessionSyncState.set.rawValue, forKey: ClerkKeychainKey.sharedSessionSyncDeviceTokenState.rawValue)
    try keychain.set("1", forKey: ClerkKeychainKey.sharedSessionSyncDeviceTokenVersion.rawValue)

    notifier.simulateNotification()

    #expect(clerk.clientResponseGeneration != initialGeneration)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "shared-token")
  }

  @Test
  func foregroundReloadAppliesSharedClientSnapshot() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)
    let sharedClient = client(id: "client-shared", signInId: "sign-in-shared", updatedAt: 2000)

    try persistSharedClient(
      sharedClient,
      state: .set,
      serverFetchDate: Date(timeIntervalSince1970: 200),
      version: 1,
      keychain: keychain
    )

    clerk.emitInternalStateChange(.applicationDidEnterForeground)

    #expect(clerk.client?.id == sharedClient.id)
    #expect(clerk.client?.signIn?.id == sharedClient.signIn?.id)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
  }

  @Test
  func signOutResponsePublishesSharedClear() async throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(
      keychain: keychain,
      notifier: notifier,
      useNetworkSessionService: true
    )
    let localClient = client(id: "client-local", signInId: "sign-in-local", updatedAt: 1000)

    clerk.applyResponseClient(localClient, serverDate: Date(timeIntervalSince1970: 100))
    let initialPostCount = notifier.postCount
    let initialAuthRevision = try #require(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue))

    let responseData = try #require("""
    {"response":null,"client":null}
    """.data(using: .utf8))
    let originalURL = try #require(URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions"))
    var mock = Mock(
      url: originalURL,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [.delete: responseData]
    )
    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "DELETE")
    }
    mock.register()

    try await clerk.auth.signOut()

    #expect(clerk.client == nil)
    #expect(notifier.postCount == initialPostCount + 1)
    #expect(try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue) == nil)
    #expect(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthState.rawValue) == SharedSessionSyncState.cleared.rawValue)
    let clearAuthRevision = try #require(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue))
    #expect(UUID(uuidString: initialAuthRevision) != nil)
    #expect(UUID(uuidString: clearAuthRevision) != nil)
    #expect(clearAuthRevision != initialAuthRevision)
  }

  @Test
  func localClientChangePublishesOnlySharedAuthMetadata() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)
    let localClient = client(id: "client-local", signInId: "sign-in-local", updatedAt: 1000)
    try keychain.set("local-attest-key-id", forKey: ClerkKeychainKey.attestKeyId.rawValue)
    try keychain.set("pending-flow", forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue)

    clerk.applyResponseClient(localClient, responseSequence: 1, serverDate: Date(timeIntervalSince1970: 100))

    #expect(notifier.postCount == 1)
    #expect(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthState.rawValue) == SharedSessionSyncState.set.rawValue)
    let authRevision = try #require(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue))
    #expect(UUID(uuidString: authRevision) != nil)
    #expect(try keychain.string(forKey: ClerkKeychainKey.attestKeyId.rawValue) == "local-attest-key-id")
    #expect(try keychain.string(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == "pending-flow")

    let cachedClientData = try #require(try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue))
    let cachedClient = try JSONDecoder.clerkDecoder.decode(Client.self, from: cachedClientData)
    #expect(cachedClient.id == localClient.id)
  }

  @Test
  func independentCoordinatorsPublishDistinctOpaqueAuthRevisions() throws {
    let keychain = InMemoryKeychain()
    let firstClerk = makeIsolatedClerk(keychain: keychain, notifier: TestSharedSessionSyncNotifier())
    let secondClerk = makeIsolatedClerk(keychain: keychain, notifier: TestSharedSessionSyncNotifier())

    firstClerk.applyResponseClient(
      client(id: "client-first", signInId: "sign-in-first", updatedAt: 1000),
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let firstRevision = try #require(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue))

    secondClerk.applyResponseClient(
      client(id: "client-second", signInId: "sign-in-second", updatedAt: 2000),
      serverDate: Date(timeIntervalSince1970: 200)
    )
    let secondRevision = try #require(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue))

    #expect(UUID(uuidString: firstRevision) != nil)
    #expect(UUID(uuidString: secondRevision) != nil)
    #expect(secondRevision != firstRevision)
  }

  @Test
  func environmentChangePublishesSharedEnvironmentVersion() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)

    clerk.environment = .mock

    #expect(notifier.postCount == 1)
    let environmentRevision = try #require(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncEnvironmentVersion.rawValue))
    #expect(UUID(uuidString: environmentRevision) != nil)
    let environmentData = try #require(try keychain.data(forKey: ClerkKeychainKey.cachedEnvironment.rawValue))
    #expect(try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: environmentData) == .mock)
  }

  @Test
  func configurationSkipsSharedSyncWithoutAccessGroup() throws {
    let clerk = Clerk()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: InMemoryKeychain()
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(sharedSessionSync: .enabled)
    )

    clerk.performConfiguration(dependencies: dependencies)

    #expect(clerk.sharedSessionSyncCoordinator == nil)
    #expect(clerk.cacheManager != nil)
  }

  @Test
  func notificationNameIsDerivedFromSharedKeychainConfig() {
    let config = Clerk.Options.KeychainConfig(
      service: "com.example.clerk",
      accessGroup: "TEAMID.com.example.clerk"
    )
    let matchingConfig = Clerk.Options.KeychainConfig(
      service: "com.example.clerk",
      accessGroup: "TEAMID.com.example.clerk"
    )
    let differentConfig = Clerk.Options.KeychainConfig(
      service: "com.example.clerk",
      accessGroup: "TEAMID.com.example.other"
    )

    let notificationName = SharedSessionSyncDarwinNotifier.notificationName(for: config)

    #expect(notificationName == SharedSessionSyncDarwinNotifier.notificationName(for: matchingConfig))
    #expect(notificationName != SharedSessionSyncDarwinNotifier.notificationName(for: differentConfig))
    #expect(notificationName.contains("TEAMID.com.example.clerk") == false)
  }

  private func makeIsolatedClerk(
    keychain: InMemoryKeychain,
    notifier: TestSharedSessionSyncNotifier? = nil,
    useNetworkSessionService: Bool = false
  ) -> Clerk {
    configureClerkForTesting()

    let clerk = Clerk()
    let apiClient = createMockAPIClient(runtimeScope: .current(clerkProvider: { clerk }))
    clerk.dependencies = MockDependencyContainer(
      apiClient: apiClient,
      keychain: keychain,
      clientService: MockClientService(get: { nil }),
      sessionService: useNetworkSessionService ? SessionService(apiClient: apiClient) : nil
    )
    try! (clerk.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: .init())

    if let notifier {
      let coordinator = SharedSessionSyncCoordinator(
        keychainConfig: .init(service: "test.service", accessGroup: "test.group"),
        clerk: clerk,
        keychain: keychain,
        notifier: notifier
      )
      clerk.sharedSessionSyncCoordinator = coordinator
      clerk.internalStateChanges.addObserver(coordinator)
    }

    return clerk
  }

  private func client(id: String, signInId: String? = nil, updatedAt: TimeInterval) -> Client {
    var client = Client.mockSignedOut
    client.id = id
    client.updatedAt = Date(timeIntervalSince1970: updatedAt)
    if let signInId {
      var signIn = SignIn.mock
      signIn.id = signInId
      client.signIn = signIn
    }
    return client
  }

  private func assertEqualDateSharedClientDoesNotReplaceLocalClient(sharedUpdatedAt: TimeInterval) throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)
    let localClient = client(id: "client-local", signInId: "sign-in-local", updatedAt: 3000)
    let staleSharedClient = client(id: "client-shared", signInId: "sign-in-shared", updatedAt: sharedUpdatedAt)

    clerk.applyResponseClient(localClient, responseSequence: 1, serverDate: Date(timeIntervalSince1970: 200))
    let initialPostCount = notifier.postCount
    try persistSharedClient(
      staleSharedClient,
      state: .set,
      serverFetchDate: Date(timeIntervalSince1970: 200),
      version: 1,
      keychain: keychain
    )

    notifier.simulateNotification()

    #expect(clerk.client?.id == localClient.id)
    #expect(clerk.client?.signIn?.id == localClient.signIn?.id)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
    #expect(notifier.postCount == initialPostCount + 1)

    let repairedClientData = try #require(try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue))
    let repairedClient = try JSONDecoder.clerkDecoder.decode(Client.self, from: repairedClientData)
    #expect(repairedClient.id == localClient.id)
    #expect(repairedClient.signIn?.id == localClient.signIn?.id)
    #expect(try loadClientServerFetchDate(from: keychain) == Date(timeIntervalSince1970: 200))
    #expect(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthState.rawValue) == SharedSessionSyncState.set.rawValue)
    let repairedRevision = try #require(try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue))
    #expect(UUID(uuidString: repairedRevision) != nil)
  }

  private func persistSharedClient(
    _ client: Client?,
    state: SharedSessionSyncState,
    serverFetchDate: Date?,
    version: Int,
    keychain: InMemoryKeychain
  ) throws {
    if let client {
      try keychain.set(JSONEncoder.clerkEncoder.encode(client), forKey: ClerkKeychainKey.cachedClient.rawValue)
    } else {
      try keychain.deleteItem(forKey: ClerkKeychainKey.cachedClient.rawValue)
    }

    if let serverFetchDate {
      try keychain.set(String(serverFetchDate.timeIntervalSince1970), forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
    } else {
      try keychain.deleteItem(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
    }

    try keychain.set(state.rawValue, forKey: ClerkKeychainKey.sharedSessionSyncAuthState.rawValue)
    try keychain.set(String(version), forKey: ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue)
  }

  private func loadClientServerFetchDate(from keychain: InMemoryKeychain) throws -> Date? {
    guard let dateString = try keychain.string(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue),
          let timeInterval = TimeInterval(dateString)
    else {
      return nil
    }

    return Date(timeIntervalSince1970: timeInterval)
  }
}

@MainActor
private final class TestSharedSessionSyncNotifier: SharedSessionSyncNotifying {
  private var handler: (@MainActor () -> Void)?
  var postCount = 0

  func setHandler(_ handler: @escaping @MainActor () -> Void) {
    self.handler = handler
  }

  func post() {
    postCount += 1
  }

  func simulateNotification() {
    handler?()
  }
}
