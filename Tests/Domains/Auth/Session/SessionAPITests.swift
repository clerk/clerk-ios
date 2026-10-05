@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
extension SessionAPIAndTokenFetcherTests {
  @Test
  func signOut() async throws {
    SessionTemplateTokensCache.shared.clear()
    let firstSession = Session.mock
    var secondSession = Session.mock
    secondSession.id = "sess_other"
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "first.jwt"),
      cacheKey: firstSession.tokenCacheKey(template: "secondary")
    )
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "second.jwt"),
      cacheKey: secondSession.tokenCacheKey(template: "secondary")
    )

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

    try await Clerk.shared.auth.signOut(sessionId: nil)
    #expect(requestHandled.value)
    #expect(SessionTemplateTokensCache.shared.getToken(
      cacheKey: firstSession.tokenCacheKey(template: "secondary")
    ) == nil)
    #expect(SessionTemplateTokensCache.shared.getToken(
      cacheKey: secondSession.tokenCacheKey(template: "secondary")
    ) == nil)
  }

  @Test
  func signOutAllAppliesTheReturnedSignedOutClient() async throws {
    SessionTemplateTokensCache.shared.clear()
    let session = Session.mock
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "session.jwt"),
      cacheKey: session.tokenCacheKey(template: "secondary")
    )
    try Clerk.shared.seedIdentity(deviceToken: "device-token", client: Client.mock, serverDate: Date(timeIntervalSince1970: 100))
    var signedOutClient = Client.mockSignedOut
    signedOutClient.id = "client-after-sign-out"
    signedOutClient.sessions = []

    let mock = try Mock(
      url: URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions")!, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: JSONEncoder.clerkEncoder.encode(ClientResponse<Client?>(response: signedOutClient, client: signedOutClient)),
      ],
      additionalHeaders: ["Authorization": "device-token"]
    )
    mock.register()

    try await Clerk.shared.auth.signOut(sessionId: nil)

    #expect(Clerk.shared.client?.id == signedOutClient.id)
    #expect(Clerk.shared.client?.sessions.isEmpty == true)
    #expect(Clerk.shared.session == nil)
    #expect(SessionTemplateTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: "secondary")
    ) == nil)
  }

  @Test
  func signOutWithSessionId() async throws {
    let sessionId = "sess_test123"
    var session = Session.mock
    session.id = sessionId
    var otherSession = Session.mock
    otherSession.id = "sess_other"
    SessionTemplateTokensCache.shared.clear()
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "default.jwt"),
      cacheKey: session.tokenCacheKey(template: "secondary")
    )
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "template.jwt"),
      cacheKey: session.tokenCacheKey(template: "firebase")
    )
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "other.jwt"),
      cacheKey: otherSession.tokenCacheKey(template: "secondary")
    )

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

    try await Clerk.shared.auth.signOut(sessionId: sessionId)
    #expect(requestHandled.value)
    #expect(SessionTemplateTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: "secondary")
    ) == nil)
    #expect(SessionTemplateTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: "firebase")
    ) == nil)
    #expect(SessionTemplateTokensCache.shared.getToken(
      cacheKey: otherSession.tokenCacheKey(template: "secondary")
    )?.jwt == "other.jwt")
  }

  @Test
  func signOutWithSessionIdPreservesCachedTokensWhenRequestFails() async throws {
    let sessionId = "sess_test123"
    var session = Session.mock
    session.id = sessionId
    SessionTemplateTokensCache.shared.clear()
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "cached.jwt"),
      cacheKey: session.tokenCacheKey(template: "secondary")
    )
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "template.jwt"),
      cacheKey: session.tokenCacheKey(template: "firebase")
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
      try await Clerk.shared.auth.signOut(sessionId: sessionId)
    }

    #expect(SessionTemplateTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: "secondary")
    )?.jwt == "cached.jwt")
    #expect(SessionTemplateTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: "firebase")
    )?.jwt == "template.jwt")
  }

  @Test
  func signOutPreservesCachedTokensWhenRequestFails() async throws {
    let session = Session.mock
    SessionTemplateTokensCache.shared.clear()
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "cached.jwt"),
      cacheKey: session.tokenCacheKey(template: "secondary")
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
      try await Clerk.shared.auth.signOut(sessionId: nil)
    }

    #expect(SessionTemplateTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: "secondary")
    )?.jwt == "cached.jwt")
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

    try await Clerk.shared.auth.setActive(sessionId: session.id, organizationId: nil)

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
    var otherSession = Session.mock
    otherSession.id = "sess_other"
    updatedClient.sessions.append(otherSession)
    var previousClient = updatedClient
    previousClient.sessions[0].lastActiveOrganizationId = nil
    Clerk.shared.client = previousClient
    SessionTemplateTokensCache.shared.clear()
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "default.jwt"),
      cacheKey: session.tokenCacheKey(template: "secondary")
    )
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "template.jwt"),
      cacheKey: session.tokenCacheKey(template: "firebase")
    )
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "other.jwt"),
      cacheKey: otherSession.tokenCacheKey(template: "secondary")
    )

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
      #expect(request.shouldAutomaticallySyncClerkClient == false)
      let body = request.urlEncodedFormBody!
      #expect(body["active_organization_id"] == organizationId)
      #expect(body["intent"] == "select_org")
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.auth.setActive(
      sessionId: session.id,
      organizationId: organizationId
    )

    #expect(requestHandled.value)
    #expect(SessionTemplateTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: "secondary")
    ) == nil)
    #expect(SessionTemplateTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: "firebase")
    ) == nil)
    #expect(SessionTemplateTokensCache.shared.getToken(
      cacheKey: otherSession.tokenCacheKey(template: "secondary")
    )?.jwt == "other.jwt")
  }

  @Test
  func setActiveInvalidatesTemplateTokenBeforePublishingSessionChange() async throws {
    let previousDeviceToken = Clerk.shared.identityController.currentDeviceToken
    let clientBeforeSeeding = Clerk.shared.client
    try Clerk.shared.seedIdentity(deviceToken: "set-active-ordering-token", client: clientBeforeSeeding)
    defer {
      try? Clerk.shared.seedIdentity(deviceToken: previousDeviceToken, client: clientBeforeSeeding)
    }

    var previousSession = Session.mock
    previousSession.lastActiveOrganizationId = "org_previous"
    var previousClient = Client.mock
    previousClient.lastActiveSessionId = previousSession.id
    previousClient.sessions = [previousSession]
    Clerk.shared.client = previousClient

    var updatedSession = previousSession
    updatedSession.lastActiveOrganizationId = "org_updated"
    var updatedClient = previousClient
    updatedClient.sessions = [updatedSession]

    let template = "firebase"
    let cacheKey = previousSession.tokenCacheKey(template: template)
    SessionTemplateTokensCache.shared.clear()
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "previous-organization.jwt"),
      cacheKey: cacheKey
    )

    let originalURL = URL(
      string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(previousSession.id)/touch"
    )!
    let mock = try Mock(
      url: originalURL,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse<Session>(response: updatedSession, client: updatedClient)
        ),
      ]
    )
    mock.register()

    let observedCacheState = AsyncStream<Bool>.makeStream(
      bufferingPolicy: .bufferingNewest(1)
    )
    let events = Clerk.shared.auth.events
    let observer = Task { @MainActor in
      for await event in events {
        guard case .sessionChanged(_, let newSession) = event,
              newSession?.lastActiveOrganizationId == updatedSession.lastActiveOrganizationId
        else {
          continue
        }

        let cachedToken = SessionTemplateTokensCache.shared.getToken(cacheKey: cacheKey)
        observedCacheState.continuation.yield(cachedToken == nil)
        return
      }
    }
    defer {
      observer.cancel()
      observedCacheState.continuation.finish()
    }

    try await Clerk.shared.auth.setActive(
      sessionId: previousSession.id,
      organizationId: updatedSession.lastActiveOrganizationId
    )

    let cacheWasEmptyWhenSessionChanged = try await waitForSessionSignal(
      observedCacheState.stream,
      message: "Timed out waiting for the updated session to be published."
    )
    #expect(cacheWasEmptyWhenSessionChanged)
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

    try await Clerk.shared.auth.setActive(
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

    try await Clerk.shared.auth.setActive(
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
    SessionTemplateTokensCache.shared.clear()
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: "cached.jwt"),
      cacheKey: session.tokenCacheKey(template: "secondary")
    )
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
      try await Clerk.shared.auth.setActive(
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

    #expect(SessionTemplateTokensCache.shared.getToken(
      cacheKey: session.tokenCacheKey(template: "secondary")
    )?.jwt == "cached.jwt")
  }

  @Test
  func fetchToken() async throws {
    let session = Session.mock
    let organizationId = "org_test456"
    let previousToken = "previous.jwt.value"
    let requestHandled = LockIsolated(false)
    let capturedBodyLogging = LockIsolated<Bool?>(nil)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/tokens")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(TokenResource.mock),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody!
      #expect(body["organization_id"] == organizationId)
      #expect(body["token"] == previousToken)
      #expect(body["force_origin"] == "true")
      capturedBodyLogging.setValue(request.shouldLogClerkBodies)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(SessionAPI.fetchToken(
      sessionId: session.id,
      template: nil,
      params: .init(
        organizationId: organizationId,
        token: previousToken,
        forceOrigin: "true"
      )
    )).value
    #expect(requestHandled.value)
    #expect(capturedBodyLogging.value == false)
  }

  @Test
  func fetchTokenForFirstMintOmitsPreviousTokenAndForceOrigin() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let capturedBodyLogging = LockIsolated<Bool?>(nil)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/tokens")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(TokenResource.mock),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      let body = request.urlEncodedFormBody!
      #expect(body["organization_id"] == "")
      #expect(body["token"] == nil)
      #expect(body["force_origin"] == nil)
      capturedBodyLogging.setValue(request.shouldLogClerkBodies)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(SessionAPI.fetchToken(
      sessionId: session.id,
      template: nil,
      params: .init(organizationId: "")
    )).value

    #expect(requestHandled.value)
    #expect(capturedBodyLogging.value == false)
  }

  @Test
  func fetchTokenWithTemplate() async throws {
    let session = Session.mock
    let template = "firebase"
    let requestHandled = LockIsolated(false)
    let capturedBodyLogging = LockIsolated<Bool?>(nil)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/tokens/\(template)")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(TokenResource.mock),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.httpBody == nil)
      capturedBodyLogging.setValue(request.shouldLogClerkBodies)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.transport.send(SessionAPI.fetchToken(
      sessionId: session.id,
      template: template,
      params: .init(
        organizationId: "org_ignored",
        token: "token_ignored",
        forceOrigin: "true"
      )
    )).value
    #expect(requestHandled.value)
    #expect(capturedBodyLogging.value == false)
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

    let verification = try await Clerk.shared.dependencies.transport.send(SessionAPI.startVerification(
      sessionId: session.id,
      params: .init(level: .firstFactor)
    )).value.response

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

    _ = try await Clerk.shared.dependencies.transport.send(SessionAPI.prepareFirstFactorVerification(
      sessionId: session.id,
      params: .init(strategy: .passkey)
    )).value.response

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

    _ = try await Clerk.shared.dependencies.transport.send(SessionAPI.prepareFirstFactorVerification(
      sessionId: session.id,
      params: .init(
        strategy: .enterpriseSSO,
        emailAddressId: "idn_email",
        enterpriseConnectionId: "econn_123",
        redirectUrl: "myapp://callback"
      )
    )).value.response

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

    let verification = try await Clerk.shared.dependencies.transport.send(SessionAPI.attemptFirstFactorVerification(
      sessionId: session.id,
      params: .init(strategy: .passkey, publicKeyCredential: "{\"id\":\"abc\"}")
    )).value.response

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

    let verification = try await Clerk.shared.dependencies.transport.send(SessionAPI.attemptSecondFactorVerification(
      sessionId: session.id,
      params: .init(strategy: .totp, code: "123456")
    )).value.response

    #expect(requestHandled.value)
    #expect(verification.status == .complete)
  }

  @Test
  func revoke() async throws {
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

    _ = try await Clerk.shared.auth.revokeSession(session)
    #expect(requestHandled.value)
  }
}

private struct SessionSignalTimeoutError: Error, CustomStringConvertible {
  let description: String
}

private func waitForSessionSignal<Value: Sendable>(
  _ stream: AsyncStream<Value>,
  timeout: Duration = .seconds(1),
  message: String
) async throws -> Value {
  try await withThrowingTaskGroup(of: Value.self) { group in
    group.addTask {
      for await value in stream {
        return value
      }
      throw SessionSignalTimeoutError(description: message)
    }
    group.addTask {
      try await Task.sleep(for: timeout)
      throw SessionSignalTimeoutError(description: message)
    }

    defer { group.cancelAll() }
    guard let value = try await group.next() else {
      throw SessionSignalTimeoutError(description: message)
    }
    return value
  }
}
