import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct UserTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func testReload() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<User>(response: user, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.reload()
    #expect(requestHandled.value)
  }

  @Test
  func testUpdate() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<User>(response: user, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["first_name"] == "John")
      #expect(request.urlEncodedFormBody!["last_name"] == "Doe")
      requestHandled.setValue(true)
    }
    mock.register()

    try await user.update(.init(firstName: "John", lastName: "Doe"))
    #expect(requestHandled.value)
  }

  @Test
  func testCreateBackupCodes() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/backup_codes")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<BackupCodeResource>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.createBackupCodes()
    #expect(requestHandled.value)
  }

  @Test
  func testCreateEmailAddress() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/email_addresses")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<EmailAddress>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["email_address"] == "new@example.com")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.createEmailAddress("new@example.com")
    #expect(requestHandled.value)
  }

  @Test
  func testCreatePhoneNumber() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/phone_numbers")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["phone_number"] == "+1234567890")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.createPhoneNumber("+1234567890")
    #expect(requestHandled.value)
  }

  @Test
  func testCreateExternalAccount() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/external_accounts")!
    let expectedRedirectUrl = Clerk.shared.options.redirectConfig.redirectUrl

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>(response: .mockVerified, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == expectedRedirectUrl)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.createExternalAccount(provider: .google)
    #expect(requestHandled.value)
  }

  @Test
  func createExternalAccountWithExplicitRedirectUrl() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/external_accounts")!
    let explicitRedirectUrl = "custom://redirect"

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>(response: .mockVerified, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == explicitRedirectUrl)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.createExternalAccount(provider: .google, redirectUrl: explicitRedirectUrl)
    #expect(requestHandled.value)
  }

  @Test
  func createExternalAccountWithAdditionalScopes() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/external_accounts")!
    let expectedRedirectUrl = Clerk.shared.options.redirectConfig.redirectUrl

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>(response: .mockVerified, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == expectedRedirectUrl)
      #expect(request.urlEncodedFormBody!["additional_scopes"] == "scope1,scope2")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.createExternalAccount(provider: .google, additionalScopes: ["scope1", "scope2"])
    #expect(requestHandled.value)
  }

  @Test
  func createExternalAccountToken() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/external_accounts")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<ExternalAccount>(response: .mockVerified, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_token_apple")
      #expect(request.urlEncodedFormBody!["token"] == "mock_id_token")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.createExternalAccount(provider: .apple, idToken: "mock_id_token")
    #expect(requestHandled.value)
  }

  @Test
  func createTotp() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/totp")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<TOTPResource>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.createTOTP()
    #expect(requestHandled.value)
  }

  @Test
  func verifyTotp() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/totp/attempt_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<TOTPResource>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.verifyTOTP(code: "123456")
    #expect(requestHandled.value)
  }

  @Test
  func disableTotp() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/totp")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.disableTOTP()
    #expect(requestHandled.value)
  }

  @Test
  func testGetOrganizationInvitations() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/organization_invitations")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<UserOrganizationInvitation>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.getOrganizationInvitations(initialPage: 0, pageSize: 10)
    #expect(requestHandled.value)
  }

  @Test
  func testGetOrganizationMemberships() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/organization_memberships")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>(
            response: ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      #expect(request.url?.query?.contains("paginated=true") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.getOrganizationMemberships(initialPage: 0, pageSize: 10)
    #expect(requestHandled.value)
  }

  @Test
  func testGetOrganizationSuggestions() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/organization_suggestions")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationSuggestion>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.getOrganizationSuggestions(initialPage: 0, pageSize: 10)
    #expect(requestHandled.value)
  }

  @Test
  func getOrganizationSuggestionsWithStatus() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/organization_suggestions")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<OrganizationSuggestion>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("offset=0") == true)
      #expect(request.url?.query?.contains("limit=10") == true)
      #expect(request.url?.query?.contains("status=active") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.getOrganizationSuggestions(initialPage: 0, pageSize: 10, status: "active")
    #expect(requestHandled.value)
  }

  @Test
  func testGetSessions() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/sessions/active")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode([Session.mock]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.getSessions()
    #expect(requestHandled.value)
  }

  @Test
  func testUpdatePassword() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/change_password")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<User>(response: user, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["new_password"] == "newPassword123")
      #expect(request.urlEncodedFormBody!["sign_out_of_other_sessions"] == "1")
      requestHandled.setValue(true)
    }
    mock.register()

    try await user.updatePassword(.init(newPassword: "newPassword123", signOutOfOtherSessions: true))
    #expect(requestHandled.value)
  }

  @Test
  func testSetProfileImage() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/profile_image")!
    let imageData = Data("fake image data".utf8)

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(
          ClientResponse<ImageResource>(
            response: ImageResource(id: "1", name: "profile", publicUrl: "https://example.com/image.jpg"),
            client: .mock
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.allHTTPHeaderFields?["Content-Type"]?.contains("multipart/form-data") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.setProfileImage(imageData: imageData)
    #expect(requestHandled.value)
  }

  @Test
  func testDeleteProfileImage() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/profile_image")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.deleteProfileImage()
    #expect(requestHandled.value)
  }

  @Test
  func testDelete() async throws {
    let user = User.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await user.delete()
    #expect(requestHandled.value)
  }
}
