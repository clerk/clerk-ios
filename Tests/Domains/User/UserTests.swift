@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct UserTests {
  private let transport = FakeTransport.mockDefaults()

  init() {
    configureClerkForTesting()
  }

  private func configureTransport() {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
    )
    try! (Clerk.shared.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: .init())
  }

  @Test
  func reloadSendsReloadRequest() async throws {
    let called = LockIsolated(false)
    transport.stub(UserAPI.reload()) { _ in
      called.setValue(true)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await User.mock.reload()

    #expect(called.value == true)
  }

  @Test
  func updateSendsProfileFields() async throws {
    let captured = LockIsolated<JSON?>(nil)
    transport.stub(UserAPI.update(params: .init())) { call in
      captured.setValue(call.body)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await User.mock.update(.init(firstName: "John", lastName: "Doe"))

    let body = try #require(captured.value)
    #expect(body["first_name"]?.stringValue == "John")
    #expect(body["last_name"]?.stringValue == "Doe")
  }

  @Test
  func updateMetadataSendsUnsafeMetadata() async throws {
    let captured = LockIsolated<JSON?>(nil)
    transport.stub(UserAPI.updateMetadata(params: .init(unsafeMetadata: .object([:])))) { call in
      captured.setValue(call.body)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await User.mock.updateMetadata(unsafeMetadata: ["token": "some-value"])

    #expect(captured.value?["unsafe_metadata"] == ["token": "some-value"])
  }

  @Test
  @available(*, deprecated)
  func updateWithIdenticalUnsafeMetadataReloadsAndDoesNotCallUpdateMetadata() async throws {
    let reloadCalls = LockIsolated(0)
    let updateCalls = LockIsolated(0)
    let metadataCalls = LockIsolated(0)
    transport.stub(UserAPI.reload()) { _ in
      reloadCalls.withValue { $0 += 1 }
      var user = User.mock
      user.unsafeMetadata = ["token": "some-value"]
      return ClientResponse(response: user, client: nil)
    }
    transport.stub(UserAPI.update(params: .init())) { _ in
      updateCalls.withValue { $0 += 1 }
      return ClientResponse(response: .mock, client: nil)
    }
    transport.stub(UserAPI.updateMetadata(params: .init(unsafeMetadata: .object([:])))) { _ in
      metadataCalls.withValue { $0 += 1 }
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    var user = User.mock
    user.unsafeMetadata = ["token": "some-value"]

    _ = try await user.update(.init(unsafeMetadata: ["token": "some-value"]))

    #expect(reloadCalls.value == 1)
    #expect(updateCalls.value == 0)
    #expect(metadataCalls.value == 0)
  }

  @Test
  @available(*, deprecated)
  func metadataOnlyDeprecatedUpdateUsesReloadedUnsafeMetadataForReplacementPatch() async throws {
    let reloadCalls = LockIsolated(0)
    let updateCalls = LockIsolated(0)
    let captured = LockIsolated<JSON?>(nil)
    transport.stub(UserAPI.reload()) { _ in
      reloadCalls.withValue { $0 += 1 }
      var user = User.mock
      user.unsafeMetadata = [
        "token": "old-value",
        "serverOnly": true,
        "nested": [
          "keep": "same",
          "remove": "old",
        ],
      ]
      return ClientResponse(response: user, client: nil)
    }
    transport.stub(UserAPI.update(params: .init())) { _ in
      updateCalls.withValue { $0 += 1 }
      return ClientResponse(response: .mock, client: nil)
    }
    transport.stub(UserAPI.updateMetadata(params: .init(unsafeMetadata: .object([:])))) { call in
      captured.setValue(call.body)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    var user = User.mock
    user.unsafeMetadata = ["token": "stale-local-value"]

    _ = try await user.update(.init(unsafeMetadata: [
      "token": "new-value",
      "nested": [
        "keep": "same",
        "added": "new",
      ],
    ]))

    #expect(reloadCalls.value == 1)
    #expect(updateCalls.value == 0)
    #expect(captured.value?["unsafe_metadata"] == [
      "token": "new-value",
      "serverOnly": .null,
      "nested": [
        "added": "new",
        "remove": .null,
      ],
    ])
  }

  @Test
  @available(*, deprecated)
  func metadataOnlyDeprecatedUpdateTreatsReloadedNilUnsafeMetadataAsEmpty() async throws {
    let captured = LockIsolated<JSON?>(nil)
    transport.stub(UserAPI.reload()) { _ in
      var user = User.mock
      user.unsafeMetadata = nil
      return ClientResponse(response: user, client: nil)
    }
    transport.stub(UserAPI.updateMetadata(params: .init(unsafeMetadata: .object([:])))) { call in
      captured.setValue(call.body)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    var user = User.mock
    user.unsafeMetadata = ["staleLocal": true]

    _ = try await user.update(.init(unsafeMetadata: ["token": "some-value"]))

    #expect(captured.value?["unsafe_metadata"] == ["token": "some-value"])
  }

  @Test
  @available(*, deprecated)
  func profileAndDeprecatedMetadataUpdateTreatsProfileResponseNilUnsafeMetadataAsEmpty() async throws {
    let reloadCalls = LockIsolated(0)
    let updateCalls = LockIsolated(0)
    let captured = LockIsolated<JSON?>(nil)
    transport.stub(UserAPI.reload()) { _ in
      reloadCalls.withValue { $0 += 1 }
      return ClientResponse(response: .mock, client: nil)
    }
    transport.stub(UserAPI.update(params: .init())) { call in
      updateCalls.withValue { $0 += 1 }
      #expect(call.body?["first_name"]?.stringValue == "John")
      var user = User.mock
      user.unsafeMetadata = nil
      return ClientResponse(response: user, client: nil)
    }
    transport.stub(UserAPI.updateMetadata(params: .init(unsafeMetadata: .object([:])))) { call in
      captured.setValue(call.body)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    var user = User.mock
    user.unsafeMetadata = ["staleLocal": true]

    _ = try await user.update(.init(
      firstName: "John",
      unsafeMetadata: ["token": "some-value"]
    ))

    #expect(reloadCalls.value == 0)
    #expect(updateCalls.value == 1)
    #expect(captured.value?["unsafe_metadata"] == ["token": "some-value"])
  }

  @Test
  func createBackupCodesSendsBackupCodesRequest() async throws {
    let called = LockIsolated(false)
    transport.stub(UserAPI.createBackupCodes()) { _ in
      called.setValue(true)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await User.mock.createBackupCodes()

    #expect(called.value == true)
  }

  @Test
  func createEmailAddressSendsEmailAddress() async throws {
    let captured = LockIsolated<JSON?>(nil)
    transport.stub(EmailAddressAPI.create(email: "")) { call in
      captured.setValue(call.body)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await User.mock.createEmailAddress("new@example.com")

    #expect(captured.value?["email_address"]?.stringValue == "new@example.com")
  }

  @Test
  func createPhoneNumberSendsPhoneNumber() async throws {
    let captured = LockIsolated<JSON?>(nil)
    transport.stub(PhoneNumberAPI.create(phoneNumber: "")) { call in
      captured.setValue(call.body)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await User.mock.createPhoneNumber("+1234567890")

    #expect(captured.value?["phone_number"]?.stringValue == "+1234567890")
  }

  struct ExternalAccountScenario: Equatable {
    let redirectUrl: String?
    let additionalScopes: [String]
    let oidcPrompts: [OIDCPrompt]
  }

  @Test(
    arguments: [
      ExternalAccountScenario(redirectUrl: nil, additionalScopes: [], oidcPrompts: []),
      ExternalAccountScenario(redirectUrl: "custom://redirect", additionalScopes: [], oidcPrompts: []),
      ExternalAccountScenario(redirectUrl: nil, additionalScopes: ["scope1", "scope2"], oidcPrompts: []),
      ExternalAccountScenario(redirectUrl: nil, additionalScopes: [], oidcPrompts: [.consent]),
    ]
  )
  func createExternalAccountSendsProviderRedirectScopesAndPrompts(
    scenario: ExternalAccountScenario
  ) async throws {
    let captured = LockIsolated<JSON?>(nil)
    transport.stub(UserAPI.createExternalAccount(provider: .google, redirectUrl: "", additionalScopes: [], oidcPrompts: [])) { call in
      captured.setValue(call.body)
      return ClientResponse(response: .mockVerified, client: nil)
    }

    configureTransport()

    _ = try await User.mock.createExternalAccount(
      provider: .google,
      redirectUrl: scenario.redirectUrl,
      additionalScopes: scenario.additionalScopes,
      oidcPrompts: scenario.oidcPrompts
    )

    let body = try #require(captured.value)
    #expect(body["strategy"]?.stringValue == OAuthProvider.google.strategy)
    #expect(body["redirect_url"]?.stringValue == scenario.redirectUrl ?? Clerk.shared.options.redirectConfig.redirectUrl)
    #expect(body["additional_scope"]?.arrayValue?.compactMap(\.stringValue) ?? [] == scenario.additionalScopes)
    #expect(body["oidc_prompt"]?.stringValue == scenario.oidcPrompts.serializedPrompt)
  }

  @Test
  func createExternalAccountWithIdTokenSendsProviderAndToken() async throws {
    let captured = LockIsolated<JSON?>(nil)
    transport.stub(UserAPI.createExternalAccountToken(provider: .apple, idToken: "")) { call in
      captured.setValue(call.body)
      return ClientResponse(response: .mockVerified, client: nil)
    }

    configureTransport()

    _ = try await User.mock.createExternalAccount(provider: .apple, idToken: "mock_id_token")

    let body = try #require(captured.value)
    #expect(body["strategy"]?.stringValue == IDTokenProvider.apple.strategy)
    #expect(body["token"]?.stringValue == "mock_id_token")
  }

  @Test
  func createTotpSendsCreateTotpRequest() async throws {
    let called = LockIsolated(false)
    transport.stub(UserAPI.createTotp()) { _ in
      called.setValue(true)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await User.mock.createTOTP()

    #expect(called.value == true)
  }

  @Test
  func verifyTotpSendsCode() async throws {
    let captured = LockIsolated<JSON?>(nil)
    transport.stub(UserAPI.verifyTotp(code: "")) { call in
      captured.setValue(call.body)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await User.mock.verifyTOTP(code: "123456")

    #expect(captured.value?["code"]?.stringValue == "123456")
  }

  @Test
  func disableTotpSendsDisableTotpRequest() async throws {
    let called = LockIsolated(false)
    transport.stub(UserAPI.disableTotp()) { _ in
      called.setValue(true)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await User.mock.disableTOTP()

    #expect(called.value == true)
  }

  @Test
  func getOrganizationInvitationsSendsPageOffsetAndStatuses() async throws {
    let captured = LockIsolated<[URLQueryItem]?>(nil)
    transport.stub(UserAPI.getOrganizationInvitations(offset: 0, pageSize: 0, status: [])) { call in
      captured.setValue(call.query)
      return ClientResponse(response: ClerkPaginatedResponse(data: [.mock], totalCount: 1), client: nil)
    }

    configureTransport()

    _ = try await User.mock.getOrganizationInvitations(page: 2, pageSize: 10, status: ["pending", "accepted"])

    let query = try #require(captured.value)
    #expect(query.first { $0.name == "offset" }?.value == "10")
    #expect(query.first { $0.name == "limit" }?.value == "10")
    #expect(query.filter { $0.name == "status" }.compactMap(\.value) == ["pending", "accepted"])
  }

  @Test
  func getOrganizationMembershipsSendsPageOffset() async throws {
    let captured = LockIsolated<[URLQueryItem]?>(nil)
    transport.stub(UserAPI.getOrganizationMemberships(offset: 0, pageSize: 0)) { call in
      captured.setValue(call.query)
      return ClientResponse(response: ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1), client: nil)
    }

    configureTransport()

    _ = try await User.mock.getOrganizationMemberships(page: 3, pageSize: 10)

    let query = try #require(captured.value)
    #expect(query.first { $0.name == "offset" }?.value == "20")
    #expect(query.first { $0.name == "limit" }?.value == "10")
  }

  @Test
  func leaveOrganizationSendsOrganizationId() async throws {
    let captured = LockIsolated<String?>(nil)
    transport.stub(UserAPI.leaveOrganization(organizationId: FakeTransport.anyPathSegment)) { call in
      captured.setValue(String(call.path.split(separator: "/")[3]))
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await User.mock.leaveOrganization(organizationId: "org_123")

    #expect(captured.value == "org_123")
  }

  struct OrganizationSuggestionsScenario: Codable, Equatable {
    let status: [String]
  }

  @Test(
    arguments: [
      OrganizationSuggestionsScenario(status: []),
      OrganizationSuggestionsScenario(status: ["pending", "accepted"]),
    ]
  )
  func getOrganizationSuggestionsSendsPageOffsetAndStatuses(
    scenario: OrganizationSuggestionsScenario
  ) async throws {
    let captured = LockIsolated<[URLQueryItem]?>(nil)
    transport.stub(UserAPI.getOrganizationSuggestions(offset: 0, pageSize: 0, status: [])) { call in
      captured.setValue(call.query)
      return ClientResponse(response: ClerkPaginatedResponse(data: [.mock], totalCount: 1), client: nil)
    }

    configureTransport()

    _ = try await User.mock.getOrganizationSuggestions(
      page: 2,
      pageSize: 10,
      status: scenario.status
    )

    let query = try #require(captured.value)
    #expect(query.first { $0.name == "offset" }?.value == "10")
    #expect(query.first { $0.name == "limit" }?.value == "10")
    #expect(query.filter { $0.name == "status" }.compactMap(\.value) == scenario.status)
  }

  @Test
  func getSessionsCachesSessionsForTheUser() async throws {
    let user = User.mock
    let called = LockIsolated(false)
    transport.stub(UserAPI.getSessions()) { _ in
      called.setValue(true)
      return [Session.mock]
    }

    configureTransport()

    _ = try await user.getSessions()

    #expect(called.value == true)
    #expect(Clerk.shared.sessionsByUserId[user.id]?.map(\.id) == [Session.mock.id])
  }

  @Test
  func updatePasswordSendsPasswordParams() async throws {
    let captured = LockIsolated<JSON?>(nil)
    transport.stub(UserAPI.updatePassword(params: .init(newPassword: "", signOutOfOtherSessions: false))) { call in
      captured.setValue(call.body)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await User.mock.updatePassword(
      .init(
        currentPassword: "currentPassword123",
        newPassword: "newPassword123",
        signOutOfOtherSessions: true
      )
    )

    let body = try #require(captured.value)
    #expect(body["current_password"]?.stringValue == "currentPassword123")
    #expect(body["new_password"]?.stringValue == "newPassword123")
    #expect(body["sign_out_of_other_sessions"]?.boolValue == true)
  }

  @Test
  func setProfileImageUploadsMultipartImageThroughTransport() async throws {
    let imageData = Data("fake image data".utf8)
    let captured = LockIsolated<FakeTransport.Call?>(nil)
    transport.stub(UserAPI.setProfileImage(boundary: "")) { call in
      captured.setValue(call)
      return ClientResponse(response: ImageResource(id: "1", name: "profile", publicUrl: "https://example.com/image.jpg"), client: nil)
    }

    configureTransport()

    _ = try await User.mock.setProfileImage(imageData: imageData)

    let call = try #require(captured.value)
    let contentType = try #require(call.headers["Content-Type"])
    #expect(contentType.hasPrefix("multipart/form-data; boundary="))
    let boundary = String(contentType.dropFirst("multipart/form-data; boundary=".count))
    let body = try #require(call.uploadBody)
    #expect(body.range(of: imageData) != nil)
    #expect(body.range(of: Data("--\(boundary)\r\n".utf8)) != nil)
    #expect(body.range(of: Data("Content-Type: image/jpeg\r\n\r\n".utf8)) != nil)
    #expect(body.suffix(boundary.utf8.count + 8) == Data("\r\n--\(boundary)--\r\n".utf8))
  }

  @Test
  func deleteProfileImageSendsDeleteProfileImageRequest() async throws {
    let called = LockIsolated(false)
    transport.stub(UserAPI.deleteProfileImage()) { _ in
      called.setValue(true)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await User.mock.deleteProfileImage()

    #expect(called.value == true)
  }

  @Test
  func deleteSendsDeleteRequest() async throws {
    let called = LockIsolated(false)
    transport.stub(UserAPI.delete()) { _ in
      called.setValue(true)
      return ClientResponse(response: .mock, client: nil)
    }

    configureTransport()

    _ = try await User.mock.delete()

    #expect(called.value == true)
  }
}
