@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkClientSyncResponseMiddlewareTests {
  @Test
  func decodeClientFromClientField() throws {
    let expectedClient = client(id: "client-field", updatedAt: .distantFuture)
    let data = try JSONEncoder.clerkEncoder.encode(ClientEnvelope(response: SignIn.mock, client: expectedClient))

    let decodedClient = ClerkClientSyncResponseMiddleware.decodeClient(from: data)
    #expect(decodedClient?.id == expectedClient.id)
  }

  @Test
  func decodeClientFromResponseFieldWhenFetchingClient() throws {
    let expectedClient = client(id: "response-field", updatedAt: .distantFuture)
    let data = try JSONEncoder.clerkEncoder.encode(ClientOnlyEnvelope(response: expectedClient, client: nil))

    let decodedClient = ClerkClientSyncResponseMiddleware.decodeClient(from: data)
    #expect(decodedClient?.id == expectedClient.id)
  }

  @Test
  func decodeClientFromErrorMetaClientField() throws {
    let expectedClient = client(id: "meta-client-field", updatedAt: .distantFuture)
    let data = try JSONEncoder.clerkEncoder.encode(ErrorMetaClientEnvelope(
      errors: [.mock],
      meta: .init(client: expectedClient)
    ))

    let decodedClient = ClerkClientSyncResponseMiddleware.decodeClient(from: data)
    #expect(decodedClient?.id == expectedClient.id)
  }

  @Test
  func decodeClientReturnsNilWhenClientCannotBeDecoded() throws {
    let data = try #require("{}".data(using: .utf8))

    #expect(ClerkClientSyncResponseMiddleware.decodeClient(from: data) == nil)
  }

  @Test
  func validatePreservesClientWhenCanonicalResponseAndClientAreNull() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    clerk.client = Client.mock
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    let data = try #require("""
    {"response":null,"client":null}
    """.data(using: .utf8))
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))
    var request = URLRequest(url: url)
    request.setClerkCanonicalClientRequest(true)

    try await middleware.validate(response, data: data, for: request)

    #expect(clerk.client?.id == Client.mock.id)
  }

  @Test
  func validateDoesNotClearClientForNonCanonicalNullFields() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let existingClient = Client.mock
    clerk.client = existingClient
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let url = try #require(URL(string: "https://example.com/v1/client/sessions/sess_123/touch"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))

    for json in [
      #"{"response":null,"client":null}"#,
      #"{"response":{"object":"session","id":"sess_123"},"client":null}"#,
      #"{"errors":[],"meta":{"client":null}}"#,
    ] {
      let data = try #require(json.data(using: .utf8))
      try await middleware.validate(response, data: data, for: URLRequest(url: url))
      #expect(clerk.client?.id == existingClient.id)
    }
  }

  @Test
  func validateAppliesSignedOutClientFromRemovedSessionEnvelope() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    clerk.client = Client.mock
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    var removedSession = Session.mock
    removedSession.status = .removed
    var signedOutClient = Client.mockSignedOut
    signedOutClient.id = "client-after-sign-out"
    signedOutClient.sessions = []
    let data = try JSONEncoder.clerkEncoder.encode(
      ClientResponse<Session>(response: removedSession, client: signedOutClient)
    )
    let url = try #require(URL(string: "https://example.com/v1/client/sessions/\(removedSession.id)/remove"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))

    var request = URLRequest(url: url)
    request.setClerkRequestDeviceToken("current-token")

    try await middleware.validate(response, data: data, for: request)

    #expect(clerk.client?.id == signedOutClient.id)
    #expect(clerk.client?.sessions.isEmpty == true)
  }

  @Test
  func validateAppliesCanonicalClientWhenSiblingClientIsNull() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let expectedClient = client(id: "canonical-client", updatedAt: .distantFuture)
    let data = try JSONEncoder.clerkEncoder.encode(
      ClientOnlyEnvelope(response: expectedClient, client: nil)
    )
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))
    var request = URLRequest(url: url)
    request.setClerkCanonicalClientRequest(true)
    request.setClerkRequestDeviceToken("current-token")

    try await middleware.validate(response, data: data, for: request)

    #expect(clerk.client?.id == expectedClient.id)
  }

  @Test
  func validateAtomicallyClearsIdentityForNativeClientDeletionContract() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    try identityStore.save(SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "current-token",
      client: Client.mock,
      serverDate: .distantPast
    ))
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      atomicIdentityStore: identityStore
    )
    try clerk.hydrateIdentityIfNeeded(#require(try identityStore.load()))
    let deletedClient = client(id: "deleted-client", updatedAt: .distantFuture)
    let data = try JSONEncoder.clerkEncoder.encode(
      ClientOnlyEnvelope(response: deletedClient, client: nil)
    )
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "Bearer "]
    ))
    var request = URLRequest(url: url)
    request.setValue("current-token", forHTTPHeaderField: "Authorization")
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)

    try await ClerkClientSyncResponseMiddleware(runtimeScope: clerk.runtimeScope)
      .validate(response, data: data, for: request)

    let stored = try #require(try identityStore.load())
    #expect(stored.state == .cleared)
    #expect(stored.deviceToken == nil)
    #expect(stored.client == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func validateUsesCapturedClerkTokenAfterCustomAuthorizationReplacement() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let initialIdentity = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "clerk-token",
      client: Client.mock,
      serverDate: .distantPast
    )
    try identityStore.save(initialIdentity)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      atomicIdentityStore: identityStore
    )
    clerk.hydrateIdentityIfNeeded(initialIdentity)
    let url = try #require(URL(string: "https://example.com/v1/client"))
    var request = URLRequest(url: url)
    try await ClerkHeaderRequestMiddleware(runtimeScope: clerk.runtimeScope)
      .prepare(&request)
    request.setValue("proxy-signature", forHTTPHeaderField: "Authorization")
    let expectedClient = client(id: "updated-client", updatedAt: .distantFuture)
    let data = try JSONEncoder.clerkEncoder.encode(
      ClientOnlyEnvelope(response: expectedClient, client: nil)
    )
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))

    try await ClerkClientSyncResponseMiddleware(runtimeScope: clerk.runtimeScope)
      .validate(response, data: data, for: request)

    let persisted = try #require(try identityStore.load())
    #expect(persisted.deviceToken == "clerk-token")
    #expect(persisted.client?.id == "updated-client")
    #expect(clerk.identityController.currentDeviceToken == "clerk-token")
  }

  @Test
  func validateAppliesClientFromClientResponseEnvelope() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    var session = Session.mock
    session.lastActiveOrganizationId = "org_test456"
    var expectedClient = Client.mock
    expectedClient.lastActiveSessionId = session.id
    expectedClient.sessions = [session]
    let data = try JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: session, client: expectedClient))
    let url = try #require(URL(string: "https://example.com/v1/client/sessions/\(session.id)/touch"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))
    var request = URLRequest(url: url)
    request.setClerkRequestDeviceToken("current-token")

    try await middleware.validate(response, data: data, for: request)

    #expect(clerk.client?.currentSession?.lastActiveOrganizationId == "org_test456")
  }

  @Test
  func validateIgnoresClientResponseFromStaleDeviceTokenGeneration() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let staleClient = client(id: "stale-client", updatedAt: .distantFuture)
    let data = try JSONEncoder.clerkEncoder.encode(ClientOnlyEnvelope(response: staleClient, client: nil))
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))
    var request = URLRequest(url: url)
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)

    clerk.identityController.clearCachedClientStateAfterDeviceTokenChange()

    try await middleware.validate(response, data: data, for: request)

    #expect(clerk.client == nil)
  }

  @Test
  func validateAppliesClientFromErrorMetaClientEnvelope() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let expectedClient = client(id: "error-meta-client", updatedAt: .distantFuture)
    let data = try JSONEncoder.clerkEncoder.encode(ErrorMetaClientEnvelope(
      errors: [.mock],
      meta: .init(client: expectedClient)
    ))
    let url = try #require(URL(string: "https://example.com/v1/client/sign_ups/sign_up_123/attempt_verification"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 400,
      httpVersion: nil,
      headerFields: nil
    ))
    var request = URLRequest(url: url)
    request.setClerkRequestDeviceToken("current-token")

    try await middleware.validate(response, data: data, for: request)

    #expect(clerk.client?.id == expectedClient.id)
  }

  @Test
  func validateDoesNotClearClientWhenPayloadHasNoClientField() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let existingClient = Client.mock
    clerk.client = existingClient
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    let data = try #require("""
    {"response":{"object":"session","id":"sess_123","status":"active"}}
    """.data(using: .utf8))
    let url = try #require(URL(string: "https://example.com/v1/me/sessions/active"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))
    let request = URLRequest(url: url)

    try await middleware.validate(response, data: data, for: request)

    #expect(clerk.client?.id == existingClient.id)
  }

  @Test
  func validateAtomicallyPersistsCompleteResponseAfterSharedTransportIsDisabled() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let previous = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "old-token",
      client: client(id: "old-client", updatedAt: .distantPast),
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try identityStore.save(previous)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      atomicIdentityStore: identityStore
    )
    clerk.hydrateIdentityIfNeeded(previous)
    let expectedClient = client(id: "new-client", updatedAt: .distantFuture)
    let data = try JSONEncoder.clerkEncoder.encode(
      ClientOnlyEnvelope(response: expectedClient, client: nil)
    )
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "new-token", "Date": "Sat, 18 Jul 2026 14:00:00 GMT"]
    ))
    var request = URLRequest(url: url)
    request.setValue("old-token", forHTTPHeaderField: "Authorization")
    request.setClerkCanonicalClientRequest(true)
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)

    try await ClerkClientSyncResponseMiddleware(runtimeScope: clerk.runtimeScope)
      .validate(response, data: data, for: request)

    let stored = try #require(try identityStore.load())
    #expect(stored.deviceToken == "new-token")
    #expect(stored.client?.id == expectedClient.id)
    #expect(clerk.client?.id == expectedClient.id)
  }

  @Test
  func validatePersistsAdoptedIdentityOffMainActor() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let previous = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "old-token",
      client: client(id: "old-client", updatedAt: .distantPast),
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let identityStore = ThreadRecordingIdentityStore(identity: previous)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      atomicIdentityStore: identityStore
    )
    clerk.hydrateIdentityIfNeeded(previous)
    let expectedClient = client(id: "new-client", updatedAt: .distantFuture)
    let data = try JSONEncoder.clerkEncoder.encode(
      ClientOnlyEnvelope(response: expectedClient, client: nil)
    )
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "new-token"]
    ))
    var request = URLRequest(url: url)
    request.setValue("old-token", forHTTPHeaderField: "Authorization")
    request.setClerkCanonicalClientRequest(true)
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)
    request.setClerkRequestSequence(1)

    try await ClerkClientSyncResponseMiddleware(runtimeScope: clerk.runtimeScope)
      .validate(response, data: data, for: request)

    #expect(identityStore.updateCount == 1)
    #expect(identityStore.mainThreadUpdateCount == 0)
    #expect(clerk.client?.id == expectedClient.id)
  }

  @Test
  func validateAtomicallyPreservesIdentityForCanonicalNullResponse() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let previous = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "token",
      client: Client.mock,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try identityStore.save(previous)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      atomicIdentityStore: identityStore
    )
    clerk.hydrateIdentityIfNeeded(previous)
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "token"]
    ))
    var request = URLRequest(url: url)
    request.setValue("token", forHTTPHeaderField: "Authorization")
    request.setClerkCanonicalClientRequest(true)
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)

    try await ClerkClientSyncResponseMiddleware(runtimeScope: clerk.runtimeScope)
      .validate(response, data: Data(#"{"response":null,"client":null}"#.utf8), for: request)

    let stored = try #require(try identityStore.load())
    #expect(stored.state == .present)
    #expect(stored.deviceToken == "token")
    #expect(stored.client?.id == Client.mock.id)
    #expect(clerk.client?.id == Client.mock.id)
  }

  private func client(id: String, updatedAt: Date) -> Client {
    var client = Client.mockSignedOut
    client.id = id
    client.updatedAt = updatedAt
    return client
  }
}

private final class ThreadRecordingIdentityStore: @unchecked Sendable, SharedSessionLocalIdentityStoring {
  private let lock = NSLock()
  private var record: SharedSessionLocalIdentityRecord?
  private var updates = 0
  private var mainThreadUpdates = 0

  init(identity: SharedSessionLocalIdentity) {
    record = SharedSessionLocalIdentityRecord(
      acceptedIdentity: identity,
      pendingPublication: nil
    )
  }

  var updateCount: Int {
    lock.withLock { updates }
  }

  var mainThreadUpdateCount: Int {
    lock.withLock { mainThreadUpdates }
  }

  func loadRecord() throws -> SharedSessionLocalIdentityRecord? {
    lock.withLock { record }
  }

  func updateRecord(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws {
    try lock.withLock {
      updates += 1
      if Thread.isMainThread {
        mainThreadUpdates += 1
      }
      record = try update(record)
    }
  }
}

private struct ClientEnvelope<Response: Codable>: Codable {
  let response: Response
  let client: Client?
}

private struct ClientOnlyEnvelope: Codable {
  let response: Client
  let client: Client?
}

private struct ErrorMetaClientEnvelope: Codable {
  let errors: [ClerkAPIError]
  let meta: Meta

  struct Meta: Codable {
    let client: Client
  }
}
