@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

extension HostedAuthFlowTests {
  @Test
  func redeemPersistsIdentityBeforeActivation() async throws {
    let createParams = LockIsolated<JSON?>(nil)
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
    let transport = hostedAuthTransport(createParams: createParams, redeemedClient: redeemedClient)
    transport.stubSetActive { sessionId, _ in
      let persisted = try Clerk.shared.dependencies.identityStore.load()
      persistedBeforeActivation.setValue(
        persisted?.deviceToken == "redeemed-token"
          && persisted?.client?.id == redeemedClient.id
          && persisted?.serverDate == Date(timeIntervalSince1970: 200)
      )
      #expect(sessionId == Session.mock2.id)
      Clerk.shared.client = activatedClient
    }
    try configureHostedAuthPersistenceTest(
      keychain: keychain,
      transport: transport
    )

    let session = try await performHostedAuth(createParams: createParams, createdSessionId: Session.mock2.id)

    #expect(persistedBeforeActivation.value)
    #expect(session.id == Session.mock2.id)
    let persisted = try #require(try Clerk.shared.dependencies.identityStore.load())
    #expect(persisted.deviceToken == "redeemed-token")
    #expect(persisted.client?.id == redeemedClient.id)
  }

  @Test
  func redeemPersistenceFailureDoesNotExposeOrActivateIdentity() async throws {
    let createParams = LockIsolated<JSON?>(nil)
    let setActiveCalled = LockIsolated(false)
    let redeemedClient = makeHostedAuthPersistenceClient(
      id: "redeemed-client",
      sessions: [.mock],
      lastActiveSessionId: Session.mock.id
    )
    let keychain = FailableIdentityKeychain()
    let transport = hostedAuthTransport(createParams: createParams, redeemedClient: redeemedClient)
    transport.stubSetActive { _, _ in setActiveCalled.setValue(true) }
    try configureHostedAuthPersistenceTest(
      keychain: keychain,
      transport: transport
    )
    keychain.failsWrites = true

    await #expect(throws: FailableIdentityKeychain.Failure.self) {
      _ = try await performHostedAuth(createParams: createParams, createdSessionId: Session.mock.id)
    }

    #expect(!setActiveCalled.value)
    #expect(Clerk.shared.client?.id == initialClient.id)
    #expect(Clerk.shared.identityController.currentDeviceToken == "initial-token")
    #expect(try Clerk.shared.dependencies.identityStore.load()?.deviceToken == "initial-token")
  }

  @Test
  func missingCallbackSessionDoesNotMutatePersistedIdentity() async throws {
    let createParams = LockIsolated<JSON?>(nil)
    let setActiveCalled = LockIsolated(false)
    let returnedClient = makeHostedAuthPersistenceClient(
      id: "wrong-client",
      sessions: [.mock],
      lastActiveSessionId: Session.mock.id
    )
    let transport = hostedAuthTransport(createParams: createParams, redeemedClient: returnedClient)
    transport.stubSetActive { _, _ in setActiveCalled.setValue(true) }
    try configureHostedAuthPersistenceTest(
      keychain: FailableIdentityKeychain(),
      transport: transport
    )

    do {
      _ = try await performHostedAuth(createParams: createParams, createdSessionId: "sess_not_in_response")
      Issue.record("Expected a redeem response missing the callback session to throw.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Hosted auth completion did not include the created session.")
    }

    #expect(!setActiveCalled.value)
    #expect(Clerk.shared.client?.id == initialClient.id)
    #expect(try Clerk.shared.dependencies.identityStore.load()?.client?.id == initialClient.id)
  }

  @Test
  func generationChangeBeforeRedeemSkipsRedeemAndPreservesIdentity() async throws {
    let createParams = LockIsolated<JSON?>(nil)
    let redeemCalled = LockIsolated(false)
    let setActiveCalled = LockIsolated(false)
    let transport = FakeTransport.mockDefaults()
    transport.stubHostedAuthCreate { body in
      createParams.setValue(body)
      return HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
    }
    transport.stubHostedAuthRedeem { _ in
      redeemCalled.setValue(true)
      return hostedAuthRedeemReply(client: .mock)
    }
    transport.stubSetActive { _, _ in setActiveCalled.setValue(true) }
    try configureHostedAuthPersistenceTest(
      keychain: FailableIdentityKeychain(),
      transport: transport
    )

    do {
      _ = try await Clerk.shared.auth.performHostedAuth(
        mode: nil,
        redirectUrl: "myapp://callback",
        prefersEphemeralWebBrowserSession: false,
        webAuthentication: { _, _, _ in
          Clerk.shared.identityController.fenceClientResponses()
          return try hostedAuthPersistenceCallbackURL(
            state: #require(createParams.value?["state"]?.stringValue),
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
    #expect(try Clerk.shared.dependencies.identityStore.load()?.client?.id == initialClient.id)
  }

  @Test
  func tokenReplacedByAnotherAppDuringRedeemRejectsResponseWithoutActivating() async throws {
    let createParams = LockIsolated<JSON?>(nil)
    let setActiveCalled = LockIsolated(false)
    let redeemedClient = makeHostedAuthPersistenceClient(
      id: "redeemed-client",
      sessions: [.mock],
      lastActiveSessionId: Session.mock.id
    )
    let otherAppClient = makeHostedAuthPersistenceClient(id: "other-app-client", sessions: [], lastActiveSessionId: nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubHostedAuthCreate { body in
      createParams.setValue(body)
      return HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
    }
    transport.stubHostedAuthRedeem { _ in
      let response = hostedAuthRedeemReply(client: redeemedClient)
      try Clerk.shared.dependencies.identityStore.save(ClerkIdentitySnapshot(
        state: .present,
        deviceToken: "other-app-token",
        client: otherAppClient,
        serverDate: Date(timeIntervalSince1970: 150)
      ))
      return response
    }
    transport.stubSetActive { _, _ in setActiveCalled.setValue(true) }
    try configureHostedAuthPersistenceTest(
      keychain: FailableIdentityKeychain(),
      identityIsInAccessGroup: true,
      transport: transport
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
    #expect(try Clerk.shared.dependencies.identityStore.load()?.client?.id == otherAppClient.id)
  }
}

private let initialClient = makeHostedAuthPersistenceClient(id: "initial-client", sessions: [], lastActiveSessionId: nil)

@MainActor
private func configureHostedAuthPersistenceTest(
  keychain: FailableIdentityKeychain,
  identityIsInAccessGroup: Bool = false,
  transport: FakeTransport
) throws {
  configureClerkForTesting()
  let clerk = Clerk.shared
  clerk.identityController.resetRuntimeIdentity()
  let dependencies = MockDependencyContainer(
    apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
    transport: transport,
    keychain: InMemoryKeychain(),
    identityKeychain: keychain,
    identityIsInAccessGroup: identityIsInAccessGroup
  )
  try dependencies.configurationManager.configure(publishableKey: testPublishableKey, options: Clerk.Options())
  clerk.dependencies = dependencies
  try clerk.seedIdentity(deviceToken: "initial-token", client: initialClient, serverDate: Date(timeIntervalSince1970: 100))
}

@MainActor
private func hostedAuthTransport(
  createParams: LockIsolated<JSON?>,
  redeemedClient: Client
) -> FakeTransport {
  let transport = FakeTransport.mockDefaults()
  transport.stubHostedAuthCreate { body in
    createParams.setValue(body)
    return HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
  }
  transport.stubHostedAuthRedeem { _ in hostedAuthRedeemReply(client: redeemedClient) }
  return transport
}

@MainActor
private func performHostedAuth(
  createParams: LockIsolated<JSON?>,
  createdSessionId: String
) async throws -> Session {
  try await Clerk.shared.auth.performHostedAuth(
    mode: nil,
    redirectUrl: "myapp://callback",
    prefersEphemeralWebBrowserSession: false,
    webAuthentication: { _, _, _ in
      try hostedAuthPersistenceCallbackURL(
        state: #require(createParams.value?["state"]?.stringValue),
        createdSessionId: createdSessionId
      )
    }
  )
}

@MainActor
private func hostedAuthRedeemReply(client: Client) -> FakeTransport.Reply<ClientResponse<Client?>> {
  FakeTransport.Reply(
    ClientResponse(response: client, client: nil),
    requestSequence: 1,
    serverDate: Date(timeIntervalSince1970: 200),
    headers: ["Authorization": "redeemed-token"]
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
