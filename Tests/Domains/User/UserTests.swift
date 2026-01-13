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
  func reloadUsesService() async throws {
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
  func updateUsesService() async throws {
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
  func createBackupCodesUsesService() async throws {
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
  func createEmailAddressUsesService() async throws {
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
  func createPhoneNumberUsesService() async throws {
    let captured = LockIsolated<String?>(nil)
    let service = MockUserService(createPhoneNumber: { phoneNumber in
      captured.setValue(phoneNumber)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.createPhoneNumber("+1234567890")

    #expect(captured.value == "+1234567890")
  }

  @Test
  func createExternalAccountUsesService() async throws {
    let captured = LockIsolated<(OAuthProvider, String?, [String]?)?>(nil)
    let service = MockUserService(createExternalAccount: { provider, redirectUrl, additionalScopes in
      captured.setValue((provider, redirectUrl, additionalScopes))
      return .mockVerified
    })

    configureService(service)

    _ = try await User.mock.createExternalAccount(provider: .google)

    let params = try #require(captured.value)
    #expect(params.0 == .google)
    #expect(params.1 == nil)
    #expect(params.2 == nil)
  }

  @Test
  func createExternalAccountWithRedirectUrlUsesService() async throws {
    let captured = LockIsolated<(OAuthProvider, String?, [String]?)?>(nil)
    let service = MockUserService(createExternalAccount: { provider, redirectUrl, additionalScopes in
      captured.setValue((provider, redirectUrl, additionalScopes))
      return .mockVerified
    })

    configureService(service)

    _ = try await User.mock.createExternalAccount(provider: .google, redirectUrl: "custom://redirect")

    let params = try #require(captured.value)
    #expect(params.0 == .google)
    #expect(params.1 == "custom://redirect")
    #expect(params.2 == nil)
  }

  @Test
  func createExternalAccountWithAdditionalScopesUsesService() async throws {
    let captured = LockIsolated<(OAuthProvider, String?, [String]?)?>(nil)
    let service = MockUserService(createExternalAccount: { provider, redirectUrl, additionalScopes in
      captured.setValue((provider, redirectUrl, additionalScopes))
      return .mockVerified
    })

    configureService(service)

    _ = try await User.mock.createExternalAccount(provider: .google, additionalScopes: ["scope1", "scope2"])

    let params = try #require(captured.value)
    #expect(params.0 == .google)
    #expect(params.1 == nil)
    #expect(params.2 == ["scope1", "scope2"])
  }

  @Test
  func createExternalAccountTokenUsesService() async throws {
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
  func createTotpUsesService() async throws {
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
  func verifyTotpUsesService() async throws {
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
  func disableTotpUsesService() async throws {
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
  func getOrganizationInvitationsUsesService() async throws {
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
  func getOrganizationMembershipsUsesService() async throws {
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

  @Test
  func getOrganizationSuggestionsUsesService() async throws {
    let captured = LockIsolated<(Int, Int, String?)?>(nil)
    let service = MockUserService(getOrganizationSuggestions: { initialPage, pageSize, status in
      captured.setValue((initialPage, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureService(service)

    _ = try await User.mock.getOrganizationSuggestions(initialPage: 0, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == 0)
    #expect(params.1 == 10)
    #expect(params.2 == nil)
  }

  @Test
  func getOrganizationSuggestionsWithStatusUsesService() async throws {
    let captured = LockIsolated<(Int, Int, String?)?>(nil)
    let service = MockUserService(getOrganizationSuggestions: { initialPage, pageSize, status in
      captured.setValue((initialPage, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureService(service)

    _ = try await User.mock.getOrganizationSuggestions(initialPage: 0, pageSize: 10, status: "active")

    let params = try #require(captured.value)
    #expect(params.0 == 0)
    #expect(params.1 == 10)
    #expect(params.2 == "active")
  }

  @Test
  func getSessionsUsesService() async throws {
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
  func updatePasswordUsesService() async throws {
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
  func setProfileImageUsesService() async throws {
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
  func deleteProfileImageUsesService() async throws {
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
  func deleteUsesService() async throws {
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
