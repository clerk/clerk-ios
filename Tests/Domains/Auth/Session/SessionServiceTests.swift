@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct SessionServiceTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func signOut() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.dependencies.sessionService.signOut(sessionId: nil)
    #expect(requestHandled.value)
  }

  @Test
  func signOutWithSessionId() async throws {
    let sessionId = "sess_test123"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/remove")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.dependencies.sessionService.signOut(sessionId: sessionId)
    #expect(requestHandled.value)
  }

  struct SetActiveErrorScenario {
    let statusCode: Int
    let errorCode: String
  }

  @Test
  func setActiveClearsOrganizationByDefault() async throws {
    var session = Session.mock
    session.lastActiveOrganizationId = nil
    var updatedClient = Client.mock
    updatedClient.lastActiveSessionId = session.id
    updatedClient.sessions = [session]

    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/touch")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: session, client: updatedClient)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody!
      #expect(body["active_organization_id"] == "")
      #expect(body["intent"] == "select_org")
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.dependencies.sessionService.setActive(sessionId: session.id, organizationId: nil)

    #expect(requestHandled.value)
  }

  @Test
  func setActiveWithOrganizationId() async throws {
    var session = Session.mock
    let organizationId = "org_test456"
    session.lastActiveOrganizationId = organizationId
    var updatedClient = Client.mock
    updatedClient.lastActiveSessionId = session.id
    updatedClient.sessions = [session]

    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/touch")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: session, client: updatedClient)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody!
      #expect(body["active_organization_id"] == organizationId)
      #expect(body["intent"] == "select_org")
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.dependencies.sessionService.setActive(
      sessionId: session.id,
      organizationId: organizationId
    )

    #expect(requestHandled.value)
  }

  @Test
  func setActiveWithNilOrganizationIdSelectsPersonalAccount() async throws {
    var session = Session.mock
    session.lastActiveOrganizationId = nil
    var updatedClient = Client.mock
    updatedClient.lastActiveSessionId = session.id
    updatedClient.sessions = [session]

    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/touch")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: session, client: updatedClient)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody!
      #expect(body["active_organization_id"] == "")
      #expect(body["intent"] == "select_org")
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.dependencies.sessionService.setActive(
      sessionId: session.id,
      organizationId: nil
    )

    #expect(requestHandled.value)
  }

  @Test
  func setActiveWithNilOrganizationIdSendsRequestWhenForcedOrganizationSelectionIsEnabled() async throws {
    var organizationSettings = Clerk.Environment.OrganizationSettings.mock
    organizationSettings.forceOrganizationSelection = true
    Clerk.shared.environment = .init(
      authConfig: .mock,
      userSettings: .mock,
      displayConfig: .mock,
      organizationSettings: organizationSettings
    )

    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(Session.mock.id)/touch")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable _ in
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.dependencies.sessionService.setActive(
      sessionId: Session.mock.id,
      organizationId: nil
    )

    #expect(requestHandled.value)
  }

  @Test(
    arguments: [
      SetActiveErrorScenario(statusCode: 401, errorCode: "unauthorized_organization"),
      SetActiveErrorScenario(statusCode: 403, errorCode: "not_a_member_in_organization"),
    ]
  )
  func setActiveWithOrganizationIdPropagatesAPIErrors(scenario: SetActiveErrorScenario) async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/touch")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: scenario.statusCode,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClerkErrorResponse(
            errors: [
              ClerkAPIError(
                code: scenario.errorCode,
                message: "Unable to switch organization",
                longMessage: nil,
                meta: nil,
                clerkTraceId: nil
              ),
            ],
            clerkTraceId: nil
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    do {
      try await Clerk.shared.dependencies.sessionService.setActive(
        sessionId: session.id,
        organizationId: "org_unauthorized"
      )
      #expect(Bool(false), "Expected API error to be thrown")
    } catch let error as ClerkAPIError {
      #expect(requestHandled.value)
      #expect(error.code == scenario.errorCode)
    } catch {
      #expect(Bool(false), "Expected ClerkAPIError, got \(error)")
    }
  }

  @Test
  func fetchToken() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/tokens")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(TokenResource.mock),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: nil,
      skipCache: false
    )
    #expect(requestHandled.value)
  }

  @Test
  func fetchTokenWithTemplate() async throws {
    let session = Session.mock
    let template = "firebase"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/tokens/\(template)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(TokenResource.mock),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: template,
      skipCache: false
    )
    #expect(requestHandled.value)
  }

  // MARK: - Session minter

  private func setEnvironment(sessionMinter: Bool) {
    Clerk.shared.environment = .init(
      authConfig: .init(singleSessionMode: false, sessionMinter: sessionMinter),
      userSettings: .mock,
      displayConfig: .mock
    )
  }

  private func registerTokensMock(
    sessionId: String,
    template: String? = nil,
    capturedBody: LockIsolated<[String: String]?>,
    capturedBodyLogging: LockIsolated<Bool?> = .init(nil),
    requestHandled: LockIsolated<Bool>
  ) throws {
    let path = if let template {
      "/v1/client/sessions/\(sessionId)/tokens/\(template)"
    } else {
      "/v1/client/sessions/\(sessionId)/tokens"
    }
    let originalURL = URL(string: mockBaseUrl.absoluteString + path)!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(TokenResource.mock),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      capturedBody.setValue(request.urlEncodedFormBody)
      capturedBodyLogging.setValue(request.shouldLogClerkBodies)
      requestHandled.setValue(true)
    }
    mock.register()
  }

  @Test
  func fetchTokenDisablesBodyLoggingWhenASeedIsAttached() async throws {
    let session = Session.mock
    setEnvironment(sessionMinter: true)
    await SessionTokensCache.shared.clear()
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "seed_jwt"),
      cacheKey: session.tokenCacheKey(template: nil)
    )

    let capturedBody = LockIsolated<[String: String]?>(nil)
    let capturedBodyLogging = LockIsolated<Bool?>(nil)
    let requestHandled = LockIsolated(false)
    try registerTokensMock(
      sessionId: session.id,
      capturedBody: capturedBody,
      capturedBodyLogging: capturedBodyLogging,
      requestHandled: requestHandled
    )

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: nil,
      skipCache: true
    )

    #expect(requestHandled.value)
    #expect(capturedBody.value?["token"] == "seed_jwt")
    #expect(capturedBodyLogging.value == false)
  }

  @Test
  func fetchTokenKeepsBodyLoggingWhenNoSeedIsAttached() async throws {
    let session = Session.mock
    setEnvironment(sessionMinter: true)
    Clerk.shared.client = .mock
    await SessionTokensCache.shared.clear()

    let capturedBody = LockIsolated<[String: String]?>(nil)
    let capturedBodyLogging = LockIsolated<Bool?>(nil)
    let requestHandled = LockIsolated(false)
    try registerTokensMock(
      sessionId: session.id,
      capturedBody: capturedBody,
      capturedBodyLogging: capturedBodyLogging,
      requestHandled: requestHandled
    )

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: nil,
      skipCache: true
    )

    #expect(requestHandled.value)
    #expect(capturedBody.value?["token"] == nil)
    #expect(capturedBodyLogging.value == true)
  }

  @Test
  func fetchTokenSendsNoBodyWhenSessionMinterIsDisabled() async throws {
    let session = Session.mock
    setEnvironment(sessionMinter: false)
    await SessionTokensCache.shared.clear()
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "seed_jwt"),
      cacheKey: session.tokenCacheKey(template: nil)
    )

    let capturedBody = LockIsolated<[String: String]?>(nil)
    let requestHandled = LockIsolated(false)
    try registerTokensMock(sessionId: session.id, capturedBody: capturedBody, requestHandled: requestHandled)

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: nil,
      skipCache: true
    )

    #expect(requestHandled.value)
    #expect(capturedBody.value == nil)
  }

  @Test
  func fetchTokenSendsCachedTokenAsSeedWhenSessionMinterIsEnabled() async throws {
    let session = Session.mock
    setEnvironment(sessionMinter: true)
    await SessionTokensCache.shared.clear()
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "seed_jwt"),
      cacheKey: session.tokenCacheKey(template: nil)
    )

    let capturedBody = LockIsolated<[String: String]?>(nil)
    let requestHandled = LockIsolated(false)
    try registerTokensMock(sessionId: session.id, capturedBody: capturedBody, requestHandled: requestHandled)

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: nil,
      skipCache: false
    )

    #expect(requestHandled.value)
    let body = try #require(capturedBody.value)
    #expect(body["token"] == "seed_jwt")
    #expect(body["force_origin"] == nil)
  }

  @Test
  func fetchTokenSendsNoBodyWhenSessionMinterIsEnabledAndNoSeedExists() async throws {
    let session = Session.mock
    setEnvironment(sessionMinter: true)
    Clerk.shared.client = .mock
    await SessionTokensCache.shared.clear()

    let capturedBody = LockIsolated<[String: String]?>(nil)
    let requestHandled = LockIsolated(false)
    try registerTokensMock(sessionId: session.id, capturedBody: capturedBody, requestHandled: requestHandled)

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: nil,
      skipCache: false
    )

    #expect(requestHandled.value)
    #expect(capturedBody.value == nil)
  }

  @Test
  func fetchTokenFallsBackToLastActiveTokenWhenCacheIsCold() async throws {
    var session = Session.mock
    session.lastActiveToken = .init(jwt: "last_active_jwt")
    var client = Client.mock
    client.sessions = [session]
    setEnvironment(sessionMinter: true)
    Clerk.shared.client = client
    await SessionTokensCache.shared.clear()

    let capturedBody = LockIsolated<[String: String]?>(nil)
    let requestHandled = LockIsolated(false)
    try registerTokensMock(sessionId: session.id, capturedBody: capturedBody, requestHandled: requestHandled)

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: nil,
      skipCache: false
    )

    #expect(requestHandled.value)
    let body = try #require(capturedBody.value)
    #expect(body["token"] == "last_active_jwt")
  }

  @Test
  func fetchTokenPrefersCachedTokenOverLastActiveToken() async throws {
    var session = Session.mock
    session.lastActiveToken = .init(jwt: "last_active_jwt")
    var client = Client.mock
    client.sessions = [session]
    setEnvironment(sessionMinter: true)
    Clerk.shared.client = client
    await SessionTokensCache.shared.clear()
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "seed_jwt"),
      cacheKey: session.tokenCacheKey(template: nil)
    )

    let capturedBody = LockIsolated<[String: String]?>(nil)
    let requestHandled = LockIsolated(false)
    try registerTokensMock(sessionId: session.id, capturedBody: capturedBody, requestHandled: requestHandled)

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: nil,
      skipCache: false
    )

    #expect(requestHandled.value)
    let body = try #require(capturedBody.value)
    #expect(body["token"] == "seed_jwt")
  }

  @Test
  func fetchTokenMapsSkipCacheToForceOrigin() async throws {
    let session = Session.mock
    setEnvironment(sessionMinter: true)
    await SessionTokensCache.shared.clear()
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "seed_jwt"),
      cacheKey: session.tokenCacheKey(template: nil)
    )

    let capturedBody = LockIsolated<[String: String]?>(nil)
    let requestHandled = LockIsolated(false)
    try registerTokensMock(sessionId: session.id, capturedBody: capturedBody, requestHandled: requestHandled)

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: nil,
      skipCache: true
    )

    #expect(requestHandled.value)
    let body = try #require(capturedBody.value)
    #expect(body["token"] == "seed_jwt")
    #expect(body["force_origin"] == "true")
  }

  @Test
  func fetchTokenWithTemplateNeverSendsMinterBody() async throws {
    let session = Session.mock
    let template = "firebase"
    setEnvironment(sessionMinter: true)
    await SessionTokensCache.shared.clear()
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "seed_jwt"),
      cacheKey: session.tokenCacheKey(template: nil)
    )

    let capturedBody = LockIsolated<[String: String]?>(nil)
    let requestHandled = LockIsolated(false)
    try registerTokensMock(
      sessionId: session.id,
      template: template,
      capturedBody: capturedBody,
      requestHandled: requestHandled
    )

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(
      sessionId: session.id,
      template: template,
      skipCache: true
    )

    #expect(requestHandled.value)
    #expect(capturedBody.value == nil)
  }

  // MARK: - Cached token invalidation

  @Test
  func signOutWithSessionIdClearsThatSessionsCachedTokens() async throws {
    let sessionId = "sess_signed_out"
    let otherSessionId = "sess_other"
    await SessionTokensCache.shared.clear()
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "seed_jwt"),
      cacheKey: Session.tokenCacheKey(sessionId: sessionId, template: nil)
    )
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "template_jwt"),
      cacheKey: Session.tokenCacheKey(sessionId: sessionId, template: "firebase")
    )
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "other_jwt"),
      cacheKey: Session.tokenCacheKey(sessionId: otherSessionId, template: nil)
    )

    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/remove")!
    let mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )
    mock.register()

    try await Clerk.shared.dependencies.sessionService.signOut(sessionId: sessionId)

    #expect(await SessionTokensCache.shared.getToken(
      cacheKey: Session.tokenCacheKey(sessionId: sessionId, template: nil)
    ) == nil)
    #expect(await SessionTokensCache.shared.getToken(
      cacheKey: Session.tokenCacheKey(sessionId: sessionId, template: "firebase")
    ) == nil)
    #expect(await SessionTokensCache.shared.getToken(
      cacheKey: Session.tokenCacheKey(sessionId: otherSessionId, template: nil)
    )?.jwt == "other_jwt")
  }

  @Test
  func signOutWithoutSessionIdClearsEveryCachedToken() async throws {
    await SessionTokensCache.shared.clear()
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "seed_jwt"),
      cacheKey: Session.tokenCacheKey(sessionId: "sess_one", template: nil)
    )
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "other_jwt"),
      cacheKey: Session.tokenCacheKey(sessionId: "sess_two", template: nil)
    )

    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions")!
    let mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )
    mock.register()

    try await Clerk.shared.dependencies.sessionService.signOut(sessionId: nil)

    #expect(await SessionTokensCache.shared.getToken(
      cacheKey: Session.tokenCacheKey(sessionId: "sess_one", template: nil)
    ) == nil)
    #expect(await SessionTokensCache.shared.getToken(
      cacheKey: Session.tokenCacheKey(sessionId: "sess_two", template: nil)
    ) == nil)
  }

  @Test
  func signOutWithSessionIdClearsCachedTokensWhenTheResponseThrows() async throws {
    let sessionId = "sess_signed_out_failing"
    await SessionTokensCache.shared.clear()
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "seed_jwt"),
      cacheKey: Session.tokenCacheKey(sessionId: sessionId, template: nil)
    )

    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/remove")!
    let mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 500,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClerkErrorResponse(
            errors: [
              ClerkAPIError(
                code: "internal_server_error",
                message: "Something went wrong",
                longMessage: nil,
                meta: nil,
                clerkTraceId: nil
              ),
            ],
            clerkTraceId: nil
          )
        ),
      ]
    )
    mock.register()

    await #expect(throws: (any Error).self) {
      try await Clerk.shared.dependencies.sessionService.signOut(sessionId: sessionId)
    }

    #expect(await SessionTokensCache.shared.getToken(
      cacheKey: Session.tokenCacheKey(sessionId: sessionId, template: nil)
    ) == nil)
  }

  @Test
  func signOutWithoutSessionIdClearsCachedTokensWhenTheResponseThrows() async throws {
    await SessionTokensCache.shared.clear()
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "seed_jwt"),
      cacheKey: Session.tokenCacheKey(sessionId: "sess_one", template: nil)
    )

    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions")!
    let mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 500,
      data: [
        .delete: JSONEncoder.clerkEncoder.encode(
          ClerkErrorResponse(
            errors: [
              ClerkAPIError(
                code: "internal_server_error",
                message: "Something went wrong",
                longMessage: nil,
                meta: nil,
                clerkTraceId: nil
              ),
            ],
            clerkTraceId: nil
          )
        ),
      ]
    )
    mock.register()

    await #expect(throws: (any Error).self) {
      try await Clerk.shared.dependencies.sessionService.signOut(sessionId: nil)
    }

    #expect(await SessionTokensCache.shared.getToken(
      cacheKey: Session.tokenCacheKey(sessionId: "sess_one", template: nil)
    ) == nil)
  }

  @Test
  func setActiveClearsThatSessionsCachedTokens() async throws {
    let session = Session.mock
    await SessionTokensCache.shared.clear()
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "seed_jwt"),
      cacheKey: session.tokenCacheKey(template: nil)
    )
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "template_jwt"),
      cacheKey: session.tokenCacheKey(template: "firebase")
    )

    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/touch")!
    let mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: session, client: .mock)),
      ]
    )
    mock.register()

    try await Clerk.shared.dependencies.sessionService.setActive(
      sessionId: session.id,
      organizationId: "org_test456"
    )

    #expect(await SessionTokensCache.shared.getToken(cacheKey: session.tokenCacheKey(template: nil)) == nil)
    #expect(await SessionTokensCache.shared.getToken(cacheKey: session.tokenCacheKey(template: "firebase")) == nil)
  }

  @Test
  func setActiveFailureKeepsCachedTokens() async throws {
    let session = Session.mock
    await SessionTokensCache.shared.clear()
    await SessionTokensCache.shared.insertToken(
      .init(jwt: "seed_jwt"),
      cacheKey: session.tokenCacheKey(template: nil)
    )

    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/touch")!
    let mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 403,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClerkErrorResponse(
            errors: [
              ClerkAPIError(
                code: "not_a_member_in_organization",
                message: "Unable to switch organization",
                longMessage: nil,
                meta: nil,
                clerkTraceId: nil
              ),
            ],
            clerkTraceId: nil
          )
        ),
      ]
    )
    mock.register()

    await #expect(throws: ClerkAPIError.self) {
      try await Clerk.shared.dependencies.sessionService.setActive(
        sessionId: session.id,
        organizationId: "org_unauthorized"
      )
    }

    #expect(await SessionTokensCache.shared.getToken(cacheKey: session.tokenCacheKey(template: nil))?.jwt == "seed_jwt")
  }

  @Test
  func startVerification() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/verify")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse<SessionVerification>(response: .mockNeedsFirstFactor, client: .mock)
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody!
      #expect(body["level"] == "first_factor")
      requestHandled.setValue(true)
    }
    mock.register()

    let verification = try await Clerk.shared.dependencies.sessionService.startVerification(
      sessionId: session.id,
      params: .init(level: .firstFactor)
    )

    #expect(requestHandled.value)
    #expect(verification.status == .needsFirstFactor)
  }

  @Test
  func prepareFirstFactorVerificationPasskey() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(
      string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/verify/prepare_first_factor"
    )!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse<SessionVerification>(response: .mockNeedsFirstFactor, client: .mock)
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody!
      #expect(body["strategy"] == "passkey")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.sessionService.prepareFirstFactorVerification(
      sessionId: session.id,
      params: .init(strategy: .passkey)
    )

    #expect(requestHandled.value)
  }

  @Test
  func prepareFirstFactorVerificationEnterpriseSSO() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(
      string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/verify/prepare_first_factor"
    )!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse<SessionVerification>(response: .mockNeedsFirstFactor, client: .mock)
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody!
      #expect(body["strategy"] == "enterprise_sso")
      #expect(body["email_address_id"] == "idn_email")
      #expect(body["enterprise_connection_id"] == "econn_123")
      #expect(body["redirect_url"] == "myapp://callback")
      #expect(body["default"] == nil)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.sessionService.prepareFirstFactorVerification(
      sessionId: session.id,
      params: .init(
        strategy: .enterpriseSSO,
        emailAddressId: "idn_email",
        enterpriseConnectionId: "econn_123",
        redirectUrl: "myapp://callback"
      )
    )

    #expect(requestHandled.value)
  }

  @Test
  func attemptFirstFactorVerificationPasskey() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(
      string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/verify/attempt_first_factor"
    )!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse<SessionVerification>(response: .mockComplete, client: .mock)
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody!
      #expect(body["strategy"] == "passkey")
      #expect(body["public_key_credential"] == "{\"id\":\"abc\"}")
      requestHandled.setValue(true)
    }
    mock.register()

    let verification = try await Clerk.shared.dependencies.sessionService.attemptFirstFactorVerification(
      sessionId: session.id,
      params: .init(strategy: .passkey, publicKeyCredential: "{\"id\":\"abc\"}")
    )

    #expect(requestHandled.value)
    #expect(verification.status == .complete)
  }

  @Test
  func attemptSecondFactorVerificationTOTP() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(
      string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/verify/attempt_second_factor"
    )!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse<SessionVerification>(response: .mockComplete, client: .mock)
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody!
      #expect(body["strategy"] == "totp")
      #expect(body["code"] == "123456")
      requestHandled.setValue(true)
    }
    mock.register()

    let verification = try await Clerk.shared.dependencies.sessionService.attemptSecondFactorVerification(
      sessionId: session.id,
      params: .init(strategy: .totp, code: "123456")
    )

    #expect(requestHandled.value)
    #expect(verification.status == .complete)
  }

  @Test
  func testRevoke() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/sessions/\(session.id)/revoke")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: session, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.sessionService.revoke(sessionId: session.id)
    #expect(requestHandled.value)
  }
}
