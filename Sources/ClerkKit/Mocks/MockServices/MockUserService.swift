//
//  MockUserService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

package final class MockUserService: UserServiceProtocol {
  package nonisolated(unsafe) var getSessionsHandler: ((User) async throws -> [Session])?

  package nonisolated(unsafe) var reloadHandler: (() async throws -> User)?

  package nonisolated(unsafe) var updateHandler: ((User.UpdateParams) async throws -> User)?

  package nonisolated(unsafe) var updateMetadataHandler: ((User.UpdateMetadataParams) async throws -> User)?

  package nonisolated(unsafe) var createBackupCodesHandler: (() async throws -> BackupCodeResource)?

  package nonisolated(unsafe) var createEmailAddressHandler: ((String) async throws -> EmailAddress)?

  package nonisolated(unsafe) var createPhoneNumberHandler: ((String) async throws -> PhoneNumber)?

  package nonisolated(unsafe) var createExternalAccountHandler: ((OAuthProvider, String?, [String], [OIDCPrompt]) async throws -> ExternalAccount)?

  package nonisolated(unsafe) var createExternalAccountTokenHandler: ((IDTokenProvider, String) async throws -> ExternalAccount)?

  #if canImport(AuthenticationServices) && !os(watchOS)
  package nonisolated(unsafe) var createPasskeyHandler: (() async throws -> Passkey)?
  #endif

  package nonisolated(unsafe) var createTotpHandler: (() async throws -> TOTPResource)?

  package nonisolated(unsafe) var verifyTotpHandler: ((String) async throws -> TOTPResource)?

  package nonisolated(unsafe) var disableTotpHandler: (() async throws -> DeletedObject)?

  /// Custom handler for the `getOrganizationInvitations(offset:pageSize:status:)` method.
  ///
  /// The closure receives the pagination arguments plus an array of invitation status filters.
  /// Pass `[]` in tests to simulate no status filter, or include one or more values such as
  /// `["pending", "accepted"]` to mirror filtered invitation requests.
  package nonisolated(unsafe) var getOrganizationInvitationsHandler: ((Int, Int, [String]) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation>)?

  package nonisolated(unsafe) var getOrganizationMembershipsHandler: ((Int, Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>)?

  package nonisolated(unsafe) var leaveOrganizationHandler: ((String) async throws -> DeletedObject)?

  /// Custom handler for the `getOrganizationSuggestions(offset:pageSize:status:)` method.
  ///
  /// The closure receives the pagination arguments plus an array of suggestion status filters.
  /// Pass `[]` in tests to simulate no status filter, or include one or more values such as
  /// `["pending", "accepted"]` to mirror filtered suggestion requests.
  package nonisolated(unsafe) var getOrganizationSuggestionsHandler: ((Int, Int, [String]) async throws -> ClerkPaginatedResponse<OrganizationSuggestion>)?

  package nonisolated(unsafe) var getOrganizationCreationDefaultsHandler: (() async throws -> OrganizationCreationDefaults)?

  package nonisolated(unsafe) var updatePasswordHandler: ((User.UpdatePasswordParams) async throws -> User)?

  package nonisolated(unsafe) var setProfileImageHandler: ((Data) async throws -> ImageResource)?

  package nonisolated(unsafe) var deleteProfileImageHandler: (() async throws -> DeletedObject)?

  package nonisolated(unsafe) var deleteHandler: (() async throws -> DeletedObject)?

  package init(
    getSessions: ((User) async throws -> [Session])? = nil,
    reload: (() async throws -> User)? = nil,
    update: ((User.UpdateParams) async throws -> User)? = nil,
    updateMetadata: ((User.UpdateMetadataParams) async throws -> User)? = nil,
    createBackupCodes: (() async throws -> BackupCodeResource)? = nil,
    createEmailAddress: ((String) async throws -> EmailAddress)? = nil,
    createPhoneNumber: ((String) async throws -> PhoneNumber)? = nil,
    createExternalAccount: ((OAuthProvider, String?, [String], [OIDCPrompt]) async throws -> ExternalAccount)? = nil,
    createExternalAccountToken: ((IDTokenProvider, String) async throws -> ExternalAccount)? = nil,
    createTotp: (() async throws -> TOTPResource)? = nil,
    verifyTotp: ((String) async throws -> TOTPResource)? = nil,
    disableTotp: (() async throws -> DeletedObject)? = nil,
    getOrganizationInvitations: ((Int, Int, [String]) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation>)? = nil,
    getOrganizationMemberships: ((Int, Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>)? = nil,
    leaveOrganization: ((String) async throws -> DeletedObject)? = nil,
    getOrganizationSuggestions: ((Int, Int, [String]) async throws -> ClerkPaginatedResponse<OrganizationSuggestion>)? = nil,
    getOrganizationCreationDefaults: (() async throws -> OrganizationCreationDefaults)? = nil,
    updatePassword: ((User.UpdatePasswordParams) async throws -> User)? = nil,
    setProfileImage: ((Data) async throws -> ImageResource)? = nil,
    deleteProfileImage: (() async throws -> DeletedObject)? = nil,
    delete: (() async throws -> DeletedObject)? = nil
  ) {
    getSessionsHandler = getSessions
    reloadHandler = reload
    updateHandler = update
    updateMetadataHandler = updateMetadata
    createBackupCodesHandler = createBackupCodes
    createEmailAddressHandler = createEmailAddress
    createPhoneNumberHandler = createPhoneNumber
    createExternalAccountHandler = createExternalAccount
    createExternalAccountTokenHandler = createExternalAccountToken
    createTotpHandler = createTotp
    verifyTotpHandler = verifyTotp
    disableTotpHandler = disableTotp
    getOrganizationInvitationsHandler = getOrganizationInvitations
    getOrganizationMembershipsHandler = getOrganizationMemberships
    leaveOrganizationHandler = leaveOrganization
    getOrganizationSuggestionsHandler = getOrganizationSuggestions
    getOrganizationCreationDefaultsHandler = getOrganizationCreationDefaults
    updatePasswordHandler = updatePassword
    setProfileImageHandler = setProfileImage
    deleteProfileImageHandler = deleteProfileImage
    deleteHandler = delete
  }

  #if canImport(AuthenticationServices) && !os(watchOS)
  package func setCreatePasskey(_ createPasskey: @escaping () async throws -> Passkey) {
    createPasskeyHandler = createPasskey
  }
  #endif

  @MainActor
  package func reload() async throws -> User {
    if let handler = reloadHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  package func update(params: User.UpdateParams) async throws -> User {
    if let handler = updateHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  package func updateMetadata(params: User.UpdateMetadataParams) async throws -> User {
    if let handler = updateMetadataHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  package func createBackupCodes() async throws -> BackupCodeResource {
    if let handler = createBackupCodesHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  package func createEmailAddress(emailAddress: String) async throws -> EmailAddress {
    if let handler = createEmailAddressHandler {
      return try await handler(emailAddress)
    }
    return .mock
  }

  @MainActor
  package func createPhoneNumber(phoneNumber: String) async throws -> PhoneNumber {
    if let handler = createPhoneNumberHandler {
      return try await handler(phoneNumber)
    }
    return .mock
  }

  @MainActor
  package func createExternalAccount(
    provider: OAuthProvider,
    redirectUrl: String?,
    additionalScopes: [String],
    oidcPrompts: [OIDCPrompt]
  ) async throws -> ExternalAccount {
    if let handler = createExternalAccountHandler {
      return try await handler(provider, redirectUrl, additionalScopes, oidcPrompts)
    }
    return .mockVerified
  }

  @MainActor
  package func createExternalAccountToken(provider: IDTokenProvider, idToken: String) async throws -> ExternalAccount {
    if let handler = createExternalAccountTokenHandler {
      return try await handler(provider, idToken)
    }
    return .mockVerified
  }

  #if canImport(AuthenticationServices) && !os(watchOS)
  @MainActor
  package func createPasskey() async throws -> Passkey {
    if let handler = createPasskeyHandler {
      return try await handler()
    }
    return .mock
  }
  #endif

  @MainActor
  package func createTotp() async throws -> TOTPResource {
    if let handler = createTotpHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  package func verifyTotp(code: String) async throws -> TOTPResource {
    if let handler = verifyTotpHandler {
      return try await handler(code)
    }
    return .mock
  }

  @MainActor
  package func disableTotp() async throws -> DeletedObject {
    if let handler = disableTotpHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  package func getOrganizationInvitations(offset: Int, pageSize: Int, status: [String]) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> {
    if let handler = getOrganizationInvitationsHandler {
      return try await handler(offset, pageSize, status)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func getOrganizationMemberships(offset: Int, pageSize: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    if let handler = getOrganizationMembershipsHandler {
      return try await handler(offset, pageSize)
    }
    return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
  }

  @MainActor
  package func leaveOrganization(organizationId: String) async throws -> DeletedObject {
    if let handler = leaveOrganizationHandler {
      return try await handler(organizationId)
    }
    return .mock
  }

  @MainActor
  package func getOrganizationSuggestions(offset: Int, pageSize: Int, status: [String]) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> {
    if let handler = getOrganizationSuggestionsHandler {
      return try await handler(offset, pageSize, status)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func getOrganizationCreationDefaults() async throws -> OrganizationCreationDefaults {
    if let handler = getOrganizationCreationDefaultsHandler {
      return try await handler()
    }
    return OrganizationCreationDefaults(
      advisory: nil,
      form: .init(name: "My organization", slug: "my-organization", logo: nil, blurHash: nil)
    )
  }

  @MainActor
  package func getSessions(user: User) async throws -> [Session] {
    if let handler = getSessionsHandler {
      return try await handler(user)
    }
    return [.mock, .mock2]
  }

  @MainActor
  package func updatePassword(params: User.UpdatePasswordParams) async throws -> User {
    if let handler = updatePasswordHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  package func setProfileImage(imageData: Data) async throws -> ImageResource {
    if let handler = setProfileImageHandler {
      return try await handler(imageData)
    }
    return ImageResource(id: "mock-image-id", name: "mock-image", publicUrl: nil)
  }

  @MainActor
  package func deleteProfileImage() async throws -> DeletedObject {
    if let handler = deleteProfileImageHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  package func delete() async throws -> DeletedObject {
    if let handler = deleteHandler {
      return try await handler()
    }
    return .mock
  }
}
