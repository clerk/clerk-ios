import ConcurrencyExtras
import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct UserTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  private func configureService(_ service: MockUserService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      userService: service
    )
  }

  @Test
  func reloadUsesUserServiceReload() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(reload: {
      called.setValue(true)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.reload()

    #expect(called.value == true)
  }

  @Test
  func updateUsesUserServiceUpdate() async throws {
    let captured = LockIsolated<User.UpdateParams?>(nil)
    let service = MockUserService(update: { params in
      captured.setValue(params)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.update(.init(firstName: "John", lastName: "Doe"))

    let params = try #require(captured.value)
    #expect(params.firstName == "John")
    #expect(params.lastName == "Doe")
  }

  @Test
  func createBackupCodesUsesUserServiceCreateBackupCodes() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(createBackupCodes: {
      called.setValue(true)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.createBackupCodes()

    #expect(called.value == true)
  }

  @Test
  func createEmailAddressUsesUserServiceCreateEmailAddress() async throws {
    let captured = LockIsolated<String?>(nil)
    let service = MockUserService(createEmailAddress: { email in
      captured.setValue(email)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.createEmailAddress("new@example.com")

    #expect(captured.value == "new@example.com")
  }

  @Test
  func createPhoneNumberUsesUserServiceCreatePhoneNumber() async throws {
    let captured = LockIsolated<String?>(nil)
    let service = MockUserService(createPhoneNumber: { phoneNumber in
      captured.setValue(phoneNumber)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.createPhoneNumber("+1234567890")

    #expect(captured.value == "+1234567890")
  }

  struct ExternalAccountScenario: Codable, Sendable, Equatable {
    let redirectUrl: String?
    let additionalScopes: [String]?
  }

  @Test(
    arguments: [
      ExternalAccountScenario(redirectUrl: nil, additionalScopes: nil),
      ExternalAccountScenario(redirectUrl: "custom://redirect", additionalScopes: nil),
      ExternalAccountScenario(redirectUrl: nil, additionalScopes: ["scope1", "scope2"]),
    ]
  )
  func createExternalAccountUsesUserServiceCreateExternalAccount(
    scenario: ExternalAccountScenario
  ) async throws {
    let captured = LockIsolated<(OAuthProvider, String?, [String]?)?>(nil)
    let service = MockUserService(createExternalAccount: { provider, redirectUrl, additionalScopes in
      captured.setValue((provider, redirectUrl, additionalScopes))
      return .mockVerified
    })

    configureService(service)

    _ = try await User.mock.createExternalAccount(
      provider: .google,
      redirectUrl: scenario.redirectUrl,
      additionalScopes: scenario.additionalScopes
    )

    let params = try #require(captured.value)
    #expect(params.0 == .google)
    #expect(params.1 == scenario.redirectUrl)
    #expect(params.2 == scenario.additionalScopes)
  }

  @Test
  func createExternalAccountTokenUsesUserServiceCreateExternalAccountToken() async throws {
    let captured = LockIsolated<(IDTokenProvider, String)?>(nil)
    let service = MockUserService(createExternalAccountToken: { provider, idToken in
      captured.setValue((provider, idToken))
      return .mockVerified
    })

    configureService(service)

    _ = try await User.mock.createExternalAccount(provider: .apple, idToken: "mock_id_token")

    let params = try #require(captured.value)
    #expect(params.0 == .apple)
    #expect(params.1 == "mock_id_token")
  }

  @Test
  func createTotpUsesUserServiceCreateTotp() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(createTotp: {
      called.setValue(true)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.createTOTP()

    #expect(called.value == true)
  }

  @Test
  func verifyTotpUsesUserServiceVerifyTotp() async throws {
    let captured = LockIsolated<String?>(nil)
    let service = MockUserService(verifyTotp: { code in
      captured.setValue(code)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.verifyTOTP(code: "123456")

    #expect(captured.value == "123456")
  }

  @Test
  func disableTotpUsesUserServiceDisableTotp() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(disableTotp: {
      called.setValue(true)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.disableTOTP()

    #expect(called.value == true)
  }

  @Test
  func getOrganizationInvitationsUsesUserServiceGetOrganizationInvitations() async throws {
    let captured = LockIsolated<(Int, Int)?>(nil)
    let service = MockUserService(getOrganizationInvitations: { initialPage, pageSize in
      captured.setValue((initialPage, pageSize))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureService(service)

    _ = try await User.mock.getOrganizationInvitations(initialPage: 0, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == 0)
    #expect(params.1 == 10)
  }

  @Test
  func getOrganizationMembershipsUsesUserServiceGetOrganizationMemberships() async throws {
    let captured = LockIsolated<(Int, Int)?>(nil)
    let service = MockUserService(getOrganizationMemberships: { initialPage, pageSize in
      captured.setValue((initialPage, pageSize))
      return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
    })

    configureService(service)

    _ = try await User.mock.getOrganizationMemberships(initialPage: 0, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == 0)
    #expect(params.1 == 10)
  }

  struct OrganizationSuggestionsScenario: Codable, Sendable, Equatable {
    let status: String?
  }

  @Test(
    arguments: [
      OrganizationSuggestionsScenario(status: nil),
      OrganizationSuggestionsScenario(status: "active"),
    ]
  )
  func getOrganizationSuggestionsUsesUserServiceGetOrganizationSuggestions(
    scenario: OrganizationSuggestionsScenario
  ) async throws {
    let captured = LockIsolated<(Int, Int, String?)?>(nil)
    let service = MockUserService(getOrganizationSuggestions: { initialPage, pageSize, status in
      captured.setValue((initialPage, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureService(service)

    _ = try await User.mock.getOrganizationSuggestions(
      initialPage: 0,
      pageSize: 10,
      status: scenario.status
    )

    let params = try #require(captured.value)
    #expect(params.0 == 0)
    #expect(params.1 == 10)
    #expect(params.2 == scenario.status)
  }

  @Test
  func getSessionsUsesUserServiceGetSessions() async throws {
    let user = User.mock
    let captured = LockIsolated<User?>(nil)
    let service = MockUserService(getSessions: { user in
      captured.setValue(user)
      return [Session.mock]
    })

    configureService(service)

    _ = try await user.getSessions()

    #expect(captured.value?.id == user.id)
  }

  @Test
  func updatePasswordUsesUserServiceUpdatePassword() async throws {
    let captured = LockIsolated<User.UpdatePasswordParams?>(nil)
    let service = MockUserService(updatePassword: { params in
      captured.setValue(params)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.updatePassword(.init(newPassword: "newPassword123", signOutOfOtherSessions: true))

    let params = try #require(captured.value)
    #expect(params.newPassword == "newPassword123")
    #expect(params.signOutOfOtherSessions == true)
  }

  @Test
  func setProfileImageUsesUserServiceSetProfileImage() async throws {
    let imageData = Data("fake image data".utf8)
    let captured = LockIsolated<Data?>(nil)
    let service = MockUserService(setProfileImage: { data in
      captured.setValue(data)
      return ImageResource(id: "1", name: "profile", publicUrl: "https://example.com/image.jpg")
    })

    configureService(service)

    _ = try await User.mock.setProfileImage(imageData: imageData)

    #expect(captured.value == imageData)
  }

  @Test
  func deleteProfileImageUsesUserServiceDeleteProfileImage() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(deleteProfileImage: {
      called.setValue(true)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.deleteProfileImage()

    #expect(called.value == true)
  }

  @Test
  func deleteUsesUserServiceDelete() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(delete: {
      called.setValue(true)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.delete()

    #expect(called.value == true)
  }
}
