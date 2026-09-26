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
      headerFields: ["Authorization": "signed-out-token"]
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
      headerFields: ["Authorization": "canonical-token"]
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
      headerFields: ["Authorization": "session-token"]
    ))

    try await middleware.validate(response, data: data, for: URLRequest(url: url))

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
      headerFields: ["Authorization": "canonical-token"]
    ))
    var request = URLRequest(url: url)
    request.setClerkCanonicalClientRequest(true)

    try await middleware.validate(response, data: data, for: request)

    #expect(clerk.client?.id == expectedClient.id)
  }

  @Test
  func validateAtomicallyClearsIdentityForNativeClientDeletionContract() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope)
    )
    try clerk.seedIdentity(deviceToken: "current-token", client: Client.mock, serverDate: .distantPast)
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

    #expect(try clerk.dependencies.identityStore.load() == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func disabledAutomaticSyncDefersClientButStillAppliesExplicitClear() async throws {
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope)
    )
    let existingClient = client(id: "existing-client", updatedAt: .distantPast)
    try clerk.seedIdentity(deviceToken: "current-token", client: existingClient)
    let incomingClient = client(id: "incoming-client", updatedAt: .distantFuture)
    let data = try JSONEncoder.clerkEncoder.encode(
      ClientOnlyEnvelope(response: incomingClient, client: nil)
    )
    let url = try #require(URL(string: "https://example.com/v1/client"))
    var request = URLRequest(url: url)
    request.disableAutomaticClerkClientSync()
    request.setClerkCanonicalClientRequest(true)
    request.setClerkRequestDeviceToken("current-token")
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: clerk.runtimeScope)
    let positiveResponse = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "rotated-token"]
    ))

    try await middleware.validate(positiveResponse, data: data, for: request)

    #expect(clerk.client?.id == existingClient.id)
    #expect(clerk.identityController.currentDeviceToken == "current-token")

    let clearResponse = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "Bearer"]
    ))
    try await middleware.validate(clearResponse, data: data, for: request)

    #expect(clerk.client == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
    #expect(try clerk.dependencies.identityStore.load() == nil)
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
    request.setValue("request-token", forHTTPHeaderField: "Authorization")
    request.setClerkRequestDeviceToken("request-token")

    try await middleware.validate(response, data: data, for: request)

    #expect(clerk.client?.currentSession?.lastActiveOrganizationId == "org_test456")
  }

  @Test
  func validateHoldsRegisteredAuthFlowBeforeApplyingCompletedSignInClient() async throws {
    configureClerkForTesting()
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    let observer = AuthFlowGateRecordingObserver()
    clerk.internalStateChanges.addObserver(observer)
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let data = try JSONEncoder.clerkEncoder.encode(ClientEnvelope(
      response: SignInResponsePayload(
        object: "sign_in_attempt",
        id: SignIn.mock.id,
        status: SignIn.Status.complete.rawValue,
        createdSessionId: Client.mock.currentSession?.id
      ),
      client: Client.mock
    ))
    let url = try #require(URL(string: "https://example.com/v1/client/sign_ins/sign_in_123/attempt_first_factor"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))
    var request = URLRequest(url: url)
    request.setClerkRequestDeviceToken("request-token")
    request.setClerkAuthFlowRegistrationId(registration.id)

    try await middleware.validate(response, data: data, for: request)

    #expect(clerk.session?.status == .active)
    #expect(clerk.isAuthFlowComplete == false)
    let snapshot = try #require(clerk.authFlowSnapshot(for: registration))
    guard case .awaiting(_, let completion) = snapshot.phase else {
      Issue.record("Expected the accepted sign-in to await post-auth work")
      return
    }
    #expect(completion?.flowId == SignIn.mock.id)
    #expect(observer.valuesAtClientChange.last == false)

    clerk.resetAuthFlow(for: registration)

    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func validateHoldsRefreshedActiveClientUntilAuthViewCompletes() async throws {
    configureClerkForTesting()
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))
    let data = try JSONEncoder.clerkEncoder.encode(ClientOnlyEnvelope(response: Client.mock, client: nil))
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))
    var request = URLRequest(url: url)
    request.setClerkRequestDeviceToken("request-token")

    try await middleware.validate(response, data: data, for: request)

    #expect(clerk.session?.status == .active)
    let snapshot = try #require(clerk.authFlowSnapshot(for: registration))
    guard case .awaiting(let work, let completion) = snapshot.phase else {
      Issue.record("Expected the externally refreshed session to be observed")
      return
    }
    #expect(completion == nil)
    #expect(clerk.isAuthFlowComplete == false)
    #expect(clerk.completeAuthFlow(work))
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
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

    clerk.identityController.fenceClientResponses()

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
    request.setValue("request-token", forHTTPHeaderField: "Authorization")
    request.setClerkRequestDeviceToken("request-token")

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
  func validatePersistsTokenAndClientTogether() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope)
    )
    try clerk.seedIdentity(
      deviceToken: "old-token",
      client: client(id: "old-client", updatedAt: .distantPast),
      serverDate: Date(timeIntervalSince1970: 100)
    )
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

    let stored = try #require(try clerk.dependencies.identityStore.load()?.identity)
    #expect(stored.deviceToken == "new-token")
    #expect(stored.client?.id == expectedClient.id)
    #expect(clerk.client?.id == expectedClient.id)
  }

  @Test
  func validatePreservesIdentityForCanonicalNullResponse() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope)
    )
    try clerk.seedIdentity(deviceToken: "token", client: Client.mock, serverDate: Date(timeIntervalSince1970: 100))
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

    let stored = try #require(try clerk.dependencies.identityStore.load()?.identity)
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

@MainActor
private final class AuthFlowGateRecordingObserver: ClerkInternalStateChangeObserver {
  private(set) var valuesAtClientChange: [Bool] = []

  func handle(_ change: ClerkInternalStateChange, from clerk: Clerk) throws {
    guard case .clientDidChange = change else { return }
    valuesAtClientChange.append(clerk.isAuthFlowComplete)
  }
}

private struct ClientEnvelope<Response: Codable>: Codable {
  let response: Response
  let client: Client?
}

private struct SignInResponsePayload: Codable {
  let object: String
  let id: String
  let status: String
  let createdSessionId: String?
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
