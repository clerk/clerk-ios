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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { _ in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(sessionId: session.id, template: nil)
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

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.sessionService.fetchToken(sessionId: session.id, template: template)
    #expect(requestHandled.value)
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.sessionService.revoke(sessionId: session.id)
    #expect(requestHandled.value)
  }
}
