@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

extension HostedAuthFlowTests {
  @Test
  func redeemPersistsIdentityBeforeActivation() async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    let persistedBeforeActivation = LockIsolated(false)
    let redeemedClient = makeHostedAuthPersistenceClient(
      id: "redeemed-client",
      sessions: [.mock, .mock2],
      lastActiveSessionId: Session.mock.id
    )
    let activatedClient = makeHostedAuthPersistenceClient(
      id: redeemedClient.id,
      sessions: redeemedClient.sessions,
      lastActiveSessionId: Session.mock2.id
    )
    let keychain = FailableIdentityKeychain()
    let sessionService = MockSessionService(setActive: { sessionId, _ in
      let persisted = try Clerk.shared.dependencies.identityStore.load()?.identity
      persistedBeforeActivation.setValue(
        persisted?.deviceToken == "redeemed-token"
          && persisted?.client?.id == redeemedClient.id
          && persisted?.serverDate == Date(timeIntervalSince1970: 200)
      )
      #expect(sessionId == Session.mock2.id)
      Clerk.shared.client = activatedClient
    })
    try configureHostedAuthPersistenceTest(
      keychain: keychain,
      hostedAuthService: hostedAuthService(createParams: createParams, redeemedClient: redeemedClient),
      sessionService: sessionService
    )

    let session = try await performHostedAuth(createParams: createParams, createdSessionId: Session.mock2.id)

    #expect(persistedBeforeActivation.value)
    #expect(session.id == Session.mock2.id)
    let persisted = try #require(try Clerk.shared.dependencies.identityStore.load()?.identity)
    #expect(persisted.deviceToken == "redeemed-token")
    #expect(persisted.client?.id == redeemedClient.id)
  }

  @Test
  func redeemPersistenceFailureDoesNotExposeOrActivateIdentity() async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    let setActiveCalled = LockIsolated(false)
    let redeemedClient = makeHostedAuthPersistenceClient(
      id: "redeemed-client",
      sessions: [.mock],
      lastActiveSessionId: Session.mock.id
    )
    let keychain = FailableIdentityKeychain()
    try configureHostedAuthPersistenceTest(
      keychain: keychain,
      hostedAuthService: hostedAuthService(createParams: createParams, redeemedClient: redeemedClient),
      sessionService: MockSessionService(setActive: { _, _ in setActiveCalled.setValue(true) })
    )
    keychain.failsWrites = true

    await #expect(throws: FailableIdentityKeychain.Failure.self) {
      _ = try await performHostedAuth(createParams: createParams, createdSessionId: Session.mock.id)
    }

    #expect(!setActiveCalled.value)
    #expect(Clerk.shared.client?.id == initialClient.id)
    #expect(Clerk.shared.identityController.currentDeviceToken == "initial-token")
    #expect(try Clerk.shared.dependencies.identityStore.load()?.identity.deviceToken == "initial-token")
  }

  @Test
  func missingCallbackSessionDoesNotMutatePersistedIdentity() async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    let setActiveCalled = LockIsolated(false)
    let returnedClient = makeHostedAuthPersistenceClient(
      id: "wrong-client",
      sessions: [.mock],
      lastActiveSessionId: Session.mock.id
    )
    try configureHostedAuthPersistenceTest(
      keychain: FailableIdentityKeychain(),
      hostedAuthService: hostedAuthService(createParams: createParams, redeemedClient: returnedClient),
      sessionService: MockSessionService(setActive: { _, _ in setActiveCalled.setValue(true) })
    )

    do {
      _ = try await performHostedAuth(createParams: createParams, createdSessionId: "sess_not_in_response")
      Issue.record("Expected a redeem response missing the callback session to throw.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Hosted auth completion did not include the created session.")
    }

    #expect(!setActiveCalled.value)
    #expect(Clerk.shared.client?.id == initialClient.id)
    #expect(try Clerk.shared.dependencies.identityStore.load()?.identity.client?.id == initialClient.id)
  }

  @Test
  func generationChangeBeforeRedeemSkipsRedeemAndPreservesIdentity() async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    let redeemCalled = LockIsolated(false)
    let setActiveCalled = LockIsolated(false)
    let hostedAuthService = MockHostedAuthService(
      create: { params in
        createParams.setValue(params)
        return HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
      },
      redeem: { _ in
        redeemCalled.setValue(true)
        return hostedAuthRedeemResponse(client: .mock)
      }
    )
    try configureHostedAuthPersistenceTest(
      keychain: FailableIdentityKeychain(),
      hostedAuthService: hostedAuthService,
      sessionService: MockSessionService(setActive: { _, _ in setActiveCalled.setValue(true) })
    )

    do {
      _ = try await Clerk.shared.auth.performHostedAuth(
        mode: nil,
        redirectUrl: "myapp://callback",
        prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in
          Clerk.shared.identityController.fenceClientResponses()
          return try hostedAuthPersistenceCallbackURL(
            state: #require(createParams.value?.state),
            createdSessionId: Session.mock.id
          )
        }
      )
      Issue.record("Expected the stale hosted-auth flow to throw.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Hosted auth completion could not update the current client.")
    }

    #expect(!redeemCalled.value)
    #expect(!setActiveCalled.value)
    #expect(Clerk.shared.client?.id == initialClient.id)
    #expect(try Clerk.shared.dependencies.identityStore.load()?.identity.client?.id == initialClient.id)
  }

  @Test
  func tokenReplacedByAnotherAppDuringRedeemRejectsResponseWithoutActivating() async throws {
    let createParams = LockIsolated<HostedAuthCreateParams?>(nil)
    let setActiveCalled = LockIsolated(false)
    let redeemedClient = makeHostedAuthPersistenceClient(
      id: "redeemed-client",
      sessions: [.mock],
      lastActiveSessionId: Session.mock.id
    )
    let otherAppClient = makeHostedAuthPersistenceClient(id: "other-app-client", sessions: [], lastActiveSessionId: nil)
    let hostedAuthService = MockHostedAuthService(
      create: { params in
        createParams.setValue(params)
        return HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
      },
      redeem: { _ in
        let response = hostedAuthRedeemResponse(client: redeemedClient)
        try Clerk.shared.dependencies.identityStore.save(ClerkIdentitySnapshot(
          state: .present,
          deviceToken: "other-app-token",
          client: otherAppClient,
          serverDate: Date(timeIntervalSince1970: 150)
        ))
        return response
      }
    )
    try configureHostedAuthPersistenceTest(
      keychain: FailableIdentityKeychain(),
      sharesIdentity: true,
      hostedAuthService: hostedAuthService,
      sessionService: MockSessionService(setActive: { _, _ in setActiveCalled.setValue(true) })
    )

    do {
      _ = try await performHostedAuth(createParams: createParams, createdSessionId: Session.mock.id)
      Issue.record("Expected the response for the replaced token to throw.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Hosted auth completion could not update the current client.")
    }

    #expect(!setActiveCalled.value)
    #expect(Clerk.shared.identityController.currentDeviceToken == "other-app-token")
    #expect(Clerk.shared.client?.id == otherAppClient.id)
    #expect(try Clerk.shared.dependencies.identityStore.load()?.identity.client?.id == otherAppClient.id)
  }
}

private let initialClient = makeHostedAuthPersistenceClient(id: "initial-client", sessions: [], lastActiveSessionId: nil)

@MainActor
private func configureHostedAuthPersistenceTest(
  keychain: FailableIdentityKeychain,
  sharesIdentity: Bool = false,
  hostedAuthService: some HostedAuthServiceProtocol,
  sessionService: some SessionServiceProtocol
) throws {
  configureClerkForTesting()
  let clerk = Clerk.shared
  clerk.identityController.resetRuntimeIdentity()
  let dependencies = MockDependencyContainer(
    apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
    keychain: InMemoryKeychain(),
    identityKeychain: keychain,
    sharesIdentity: sharesIdentity,
    hostedAuthService: hostedAuthService,
    sessionService: sessionService
  )
  try dependencies.configurationManager.configure(publishableKey: testPublishableKey, options: Clerk.Options())
  clerk.dependencies = dependencies
  try clerk.seedIdentity(deviceToken: "initial-token", client: initialClient, serverDate: Date(timeIntervalSince1970: 100))
  if sharesIdentity {
    clerk.identityController.startSharing(notifier: SilentNotifier())
  }
}

@MainActor
private func hostedAuthService(
  createParams: LockIsolated<HostedAuthCreateParams?>,
  redeemedClient: Client
) -> MockHostedAuthService {
  MockHostedAuthService(
    create: { params in
      createParams.setValue(params)
      return HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
    },
    redeem: { _ in hostedAuthRedeemResponse(client: redeemedClient) }
  )
}

@MainActor
private func performHostedAuth(
  createParams: LockIsolated<HostedAuthCreateParams?>,
  createdSessionId: String
) async throws -> Session {
  try await Clerk.shared.auth.performHostedAuth(
    mode: nil,
    redirectUrl: "myapp://callback",
    prefersEphemeralWebBrowserSession: false,
    webAuthentication: { _, _, _ in
      try hostedAuthPersistenceCallbackURL(
        state: #require(createParams.value?.state),
        createdSessionId: createdSessionId
      )
    }
  )
}

@MainActor
private func hostedAuthRedeemResponse(client: Client) -> HostedAuthRedeemResponse {
  HostedAuthRedeemResponse(
    client: client,
    clientSyncContext: ClientSyncResponseContext(
      update: .client(client),
      deviceTokenUpdate: .set("redeemed-token"),
      requestDeviceToken: "initial-token",
      serverDate: Date(timeIntervalSince1970: 200),
      isCanonicalClientRequest: true,
      clientResponseGeneration: Clerk.shared.clientResponseGeneration,
      responseSequence: 1
    )
  )
}

private func makeHostedAuthPersistenceClient(
  id: String,
  sessions: [Session],
  lastActiveSessionId: String?
) -> Client {
  var client = Client.mockSignedOut
  client.id = id
  client.sessions = sessions
  client.lastActiveSessionId = lastActiveSessionId
  return client
}

private func hostedAuthPersistenceCallbackURL(
  state: String,
  createdSessionId: String
) throws -> URL {
  var components = try #require(URLComponents(string: "myapp://callback"))
  components.queryItems = [
    URLQueryItem(name: "state", value: state),
    URLQueryItem(name: "rotating_token_nonce", value: "nonce_123"),
    URLQueryItem(name: "created_session_id", value: createdSessionId),
  ]
  return try #require(components.url)
}

private final class FailableIdentityKeychain: @unchecked Sendable, KeychainStorage {
  enum Failure: Error {
    case write
  }

  private let backing = InMemoryKeychain()
  private let lock = NSLock()
  private var shouldFail = false

  var failsWrites: Bool {
    get { lock.withLock { shouldFail } }
    set { lock.withLock { shouldFail = newValue } }
  }

  func set(_ data: Data, forKey key: String) throws {
    guard !failsWrites else { throw Failure.write }
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try backing.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    guard !failsWrites else { throw Failure.write }
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }
}

@MainActor
private final class SilentNotifier: SharedSessionSyncNotifying {
  func setHandler(_: @escaping @MainActor () -> Void) {}
  func post() {}
}
