@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct AccountFacadeTests {
  private let fixture = ClerkTestFixture()

  private func makeClerk(
    userService: MockUserService,
    emailAddressService: MockEmailAddressService? = nil,
    phoneNumberService: MockPhoneNumberService? = nil,
    options: Clerk.Options = .init()
  ) throws -> Clerk {
    try fixture.makeClerk(
      userService: userService,
      emailAddressService: emailAddressService,
      phoneNumberService: phoneNumberService,
      options: options,
      environment: .mock
    )
  }

  @Test
  func reloadUsesUserServiceReload() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(reload: { _ in
      called.setValue(true)
      return .mock
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.reload()

    #expect(called.value == true)
  }

  @Test
  func updateUsesUserServiceUpdate() async throws {
    let captured = LockIsolated<User.UpdateParams?>(nil)
    let service = MockUserService(update: { params, _ in
      captured.setValue(params)
      return .mock
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.update(.init(firstName: "John", lastName: "Doe"))

    let params = try #require(captured.value)
    #expect(params.firstName == "John")
    #expect(params.lastName == "Doe")
  }

  @Test
  func createBackupCodesUsesUserServiceCreateBackupCodes() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(createBackupCodes: { _ in
      called.setValue(true)
      return .mock
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.createBackupCodes()

    #expect(called.value == true)
  }

  @Test
  func createEmailAddressUsesEmailAddressServiceCreate() async throws {
    let captured = LockIsolated<String?>(nil)
    let service = MockEmailAddressService(create: { email in
      captured.setValue(email)
      return .mock
    })
    let clerk = try makeClerk(userService: MockUserService(), emailAddressService: service)

    _ = try await clerk.account.createEmailAddress("new@example.com")

    #expect(captured.value == "new@example.com")
  }

  @Test
  func createPhoneNumberUsesPhoneNumberServiceCreate() async throws {
    let captured = LockIsolated<String?>(nil)
    let service = MockPhoneNumberService(create: { phoneNumber, _ in
      captured.setValue(phoneNumber)
      return .mock
    })
    let clerk = try makeClerk(userService: MockUserService(), phoneNumberService: service)

    _ = try await clerk.account.createPhoneNumber("+1234567890")

    #expect(captured.value == "+1234567890")
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
  func createExternalAccountUsesUserServiceCreateExternalAccount(
    scenario: ExternalAccountScenario
  ) async throws {
    let captured = LockIsolated<(OAuthProvider, String?, [String], [OIDCPrompt], String?)?>(nil)
    let service = MockUserService(createExternalAccount: { provider, redirectUrl, additionalScopes, oidcPrompts, sessionId in
      captured.setValue((provider, redirectUrl, additionalScopes, oidcPrompts, sessionId))
      return .mockVerified
    })
    let clerk = try makeClerk(userService: service)
    clerk.client = .mock
    let sessionId = try #require(clerk.session?.id)

    _ = try await clerk.account.createExternalAccount(
      provider: .google,
      redirectUrl: scenario.redirectUrl,
      additionalScopes: scenario.additionalScopes,
      oidcPrompts: scenario.oidcPrompts
    )

    let params = try #require(captured.value)
    #expect(params.0 == .google)
    #expect(params.1 == scenario.redirectUrl ?? clerk.options.redirectConfig.redirectUrl)
    #expect(params.2 == scenario.additionalScopes)
    #expect(params.3 == scenario.oidcPrompts)
    #expect(params.4 == sessionId)
  }

  @Test
  func createExternalAccountTokenUsesUserServiceCreateExternalAccountToken() async throws {
    let captured = LockIsolated<(IDTokenProvider, String)?>(nil)
    let service = MockUserService(createExternalAccountToken: { provider, idToken, _ in
      captured.setValue((provider, idToken))
      return .mockVerified
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.createExternalAccount(provider: .apple, idToken: "mock_id_token")

    let params = try #require(captured.value)
    #expect(params.0 == .apple)
    #expect(params.1 == "mock_id_token")
  }

  @Test
  func createTotpUsesUserServiceCreateTotp() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(createTotp: { _ in
      called.setValue(true)
      return .mock
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.createTOTP()

    #expect(called.value == true)
  }

  @Test
  func verifyTotpUsesUserServiceVerifyTotp() async throws {
    let captured = LockIsolated<String?>(nil)
    let service = MockUserService(verifyTotp: { code, _ in
      captured.setValue(code)
      return .mock
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.verifyTOTP("123456")

    #expect(captured.value == "123456")
  }

  @Test
  func disableTotpUsesUserServiceDisableTotp() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(disableTotp: { _ in
      called.setValue(true)
      return .mock
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.disableTOTP()

    #expect(called.value == true)
  }

  @Test
  func getOrganizationInvitationsUsesUserServiceGetOrganizationInvitations() async throws {
    let captured = LockIsolated<(Int, Int, String?)?>(nil)
    let service = MockUserService(getOrganizationInvitations: { offset, pageSize, status, _ in
      captured.setValue((offset, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.getOrganizationInvitations(page: 2, pageSize: 10, status: "pending")

    let params = try #require(captured.value)
    #expect(params.0 == 10)
    #expect(params.1 == 10)
    #expect(params.2 == "pending")
  }

  @Test
  func getOrganizationMembershipsUsesUserServiceGetOrganizationMemberships() async throws {
    let captured = LockIsolated<(Int, Int)?>(nil)
    let service = MockUserService(getOrganizationMemberships: { offset, pageSize, _ in
      captured.setValue((offset, pageSize))
      return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.getOrganizationMemberships(page: 3, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == 20)
    #expect(params.1 == 10)
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
  func getOrganizationSuggestionsUsesUserServiceGetOrganizationSuggestions(
    scenario: OrganizationSuggestionsScenario
  ) async throws {
    let captured = LockIsolated<(Int, Int, [String])?>(nil)
    let service = MockUserService(getOrganizationSuggestions: { offset, pageSize, status, _ in
      captured.setValue((offset, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.getOrganizationSuggestions(
      page: 2,
      pageSize: 10,
      status: scenario.status
    )

    let params = try #require(captured.value)
    #expect(params.0 == 10)
    #expect(params.1 == 10)
    #expect(params.2 == scenario.status)
  }

  @Test
  func getSessionsUsesUserServiceGetSessions() async throws {
    let user = User.mock
    let called = LockIsolated(false)
    let capturedSessionId = LockIsolated<String?>(nil)
    let service = MockUserService(getSessions: { sessionId in
      called.setValue(true)
      capturedSessionId.setValue(sessionId)
      return [Session.mock]
    })
    let clerk = try makeClerk(userService: service)
    clerk.client = .mock
    #expect(clerk.user?.id == user.id)
    let sessionId = try #require(clerk.session?.id)

    let sessions = try await clerk.account.getSessions(for: user)

    #expect(called.value == true)
    #expect(capturedSessionId.value == sessionId)
    #expect(sessions.map(\.id) == [Session.mock.id])
    #expect(clerk.sessionsByUserId[user.id]?.map(\.id) == [Session.mock.id])
  }

  @Test
  func getSessionsThrowsWhenUserIsNotActiveUser() async throws {
    let user = User.mock2
    let called = LockIsolated(false)
    let service = MockUserService(getSessions: { _ in
      called.setValue(true)
      return [Session.mock]
    })
    let clerk = try makeClerk(userService: service)
    clerk.client = .mock

    do {
      _ = try await clerk.account.getSessions(for: user)
      Issue.record("Expected getSessions to throw for a non-active user.")
    } catch let error as ClerkClientError {
      #expect(error.message?.contains("Cannot get sessions") == true)
    } catch {
      Issue.record("Expected ClerkClientError, got \(error).")
    }

    #expect(called.value == false)
    #expect(clerk.sessionsByUserId[user.id] == nil)
  }

  @Test
  func updatePasswordUsesUserServiceUpdatePassword() async throws {
    let captured = LockIsolated<User.UpdatePasswordParams?>(nil)
    let service = MockUserService(updatePassword: { params, _ in
      captured.setValue(params)
      return .mock
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.updatePassword(.init(newPassword: "newPassword123", signOutOfOtherSessions: true))

    let params = try #require(captured.value)
    #expect(params.newPassword == "newPassword123")
    #expect(params.signOutOfOtherSessions == true)
  }

  @Test
  func setProfileImageUsesUserServiceSetProfileImage() async throws {
    let imageData = Data("fake image data".utf8)
    let captured = LockIsolated<Data?>(nil)
    let service = MockUserService(setProfileImage: { data, _ in
      captured.setValue(data)
      return ImageResource(id: "1", name: "profile", publicUrl: "https://example.com/image.jpg")
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.setProfileImage(imageData: imageData)

    #expect(captured.value == imageData)
  }

  @Test
  func deleteProfileImageUsesUserServiceDeleteProfileImage() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(deleteProfileImage: { _ in
      called.setValue(true)
      return .mock
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.deleteProfileImage()

    #expect(called.value == true)
  }

  @Test
  func deleteUsesUserServiceDelete() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(delete: { _ in
      called.setValue(true)
      return .mock
    })
    let clerk = try makeClerk(userService: service)

    _ = try await clerk.account.delete()

    #expect(called.value == true)
  }
}
