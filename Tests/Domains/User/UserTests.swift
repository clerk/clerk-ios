@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct UserTests {
  init() {
    configureClerkForTesting()
  }

  private func configureService(_ service: MockUserService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      userService: service
    )
    try! (Clerk.shared.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: .init())
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
  func updateMetadataUsesUserServiceUpdateMetadata() async throws {
    let captured = LockIsolated<User.UpdateMetadataParams?>(nil)
    let service = MockUserService(updateMetadata: { params in
      captured.setValue(params)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.updateMetadata(unsafeMetadata: ["token": "some-value"])

    #expect(captured.value?.unsafeMetadata == ["token": "some-value"])
  }

  @Test
  @available(*, deprecated)
  func updateWithIdenticalUnsafeMetadataReloadsAndDoesNotCallUpdateMetadata() async throws {
    let reloadCalls = LockIsolated(0)
    let updateCalls = LockIsolated(0)
    let metadataCalls = LockIsolated(0)
    let service = MockUserService(
      reload: {
        reloadCalls.withValue { $0 += 1 }
        var user = User.mock
        user.unsafeMetadata = ["token": "some-value"]
        return user
      },
      update: { _ in
        updateCalls.withValue { $0 += 1 }
        return .mock
      },
      updateMetadata: { _ in
        metadataCalls.withValue { $0 += 1 }
        return .mock
      }
    )

    configureService(service)

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
    let captured = LockIsolated<User.UpdateMetadataParams?>(nil)
    let service = MockUserService(
      reload: {
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
        return user
      },
      update: { _ in
        updateCalls.withValue { $0 += 1 }
        return .mock
      },
      updateMetadata: { params in
        captured.setValue(params)
        return .mock
      }
    )

    configureService(service)

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
    #expect(captured.value?.unsafeMetadata == [
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
    let captured = LockIsolated<User.UpdateMetadataParams?>(nil)
    let service = MockUserService(
      reload: {
        var user = User.mock
        user.unsafeMetadata = nil
        return user
      },
      updateMetadata: { params in
        captured.setValue(params)
        return .mock
      }
    )

    configureService(service)

    var user = User.mock
    user.unsafeMetadata = ["staleLocal": true]

    _ = try await user.update(.init(unsafeMetadata: ["token": "some-value"]))

    #expect(captured.value?.unsafeMetadata == ["token": "some-value"])
  }

  @Test
  @available(*, deprecated)
  func profileAndDeprecatedMetadataUpdateTreatsProfileResponseNilUnsafeMetadataAsEmpty() async throws {
    let reloadCalls = LockIsolated(0)
    let updateCalls = LockIsolated(0)
    let captured = LockIsolated<User.UpdateMetadataParams?>(nil)
    let service = MockUserService(
      reload: {
        reloadCalls.withValue { $0 += 1 }
        return .mock
      },
      update: { params in
        updateCalls.withValue { $0 += 1 }
        #expect(params.firstName == "John")
        var user = User.mock
        user.unsafeMetadata = nil
        return user
      },
      updateMetadata: { params in
        captured.setValue(params)
        return .mock
      }
    )

    configureService(service)

    var user = User.mock
    user.unsafeMetadata = ["staleLocal": true]

    _ = try await user.update(.init(
      firstName: "John",
      unsafeMetadata: ["token": "some-value"]
    ))

    #expect(reloadCalls.value == 0)
    #expect(updateCalls.value == 1)
    #expect(captured.value?.unsafeMetadata == ["token": "some-value"])
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
    let captured = LockIsolated<(OAuthProvider, String?, [String], [OIDCPrompt])?>(nil)
    let service = MockUserService(createExternalAccount: { provider, redirectUrl, additionalScopes, oidcPrompts in
      captured.setValue((provider, redirectUrl, additionalScopes, oidcPrompts))
      return .mockVerified
    })

    configureService(service)

    _ = try await User.mock.createExternalAccount(
      provider: .google,
      redirectUrl: scenario.redirectUrl,
      additionalScopes: scenario.additionalScopes,
      oidcPrompts: scenario.oidcPrompts
    )

    let params = try #require(captured.value)
    #expect(params.0 == .google)
    #expect(params.1 == scenario.redirectUrl)
    #expect(params.2 == scenario.additionalScopes)
    #expect(params.3 == scenario.oidcPrompts)
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
    let captured = LockIsolated<(Int, Int, [String])?>(nil)
    let service = MockUserService(getOrganizationInvitations: { offset, pageSize, status in
      captured.setValue((offset, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureService(service)

    _ = try await User.mock.getOrganizationInvitations(page: 2, pageSize: 10, status: ["pending", "accepted"])

    let params = try #require(captured.value)
    #expect(params.0 == 10)
    #expect(params.1 == 10)
    #expect(params.2 == ["pending", "accepted"])
  }

  @Test
  func getOrganizationMembershipsUsesUserServiceGetOrganizationMemberships() async throws {
    let captured = LockIsolated<(Int, Int)?>(nil)
    let service = MockUserService(getOrganizationMemberships: { offset, pageSize in
      captured.setValue((offset, pageSize))
      return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
    })

    configureService(service)

    _ = try await User.mock.getOrganizationMemberships(page: 3, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == 20)
    #expect(params.1 == 10)
  }

  @Test
  func leaveOrganizationUsesUserServiceLeaveOrganization() async throws {
    let captured = LockIsolated<String?>(nil)
    let service = MockUserService(leaveOrganization: { organizationId in
      captured.setValue(organizationId)
      return .mock
    })

    configureService(service)

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
  func getOrganizationSuggestionsUsesUserServiceGetOrganizationSuggestions(
    scenario: OrganizationSuggestionsScenario
  ) async throws {
    let captured = LockIsolated<(Int, Int, [String])?>(nil)
    let service = MockUserService(getOrganizationSuggestions: { offset, pageSize, status in
      captured.setValue((offset, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureService(service)

    _ = try await User.mock.getOrganizationSuggestions(
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
