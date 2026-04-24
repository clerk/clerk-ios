//
//  MockUserService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Mock implementation of `UserServiceProtocol` for testing and previews.
///
/// Allows customizing the behavior of service methods through handler closures.
/// All methods return default mock values if handlers are not provided.
package final class MockUserService: UserServiceProtocol {
  /// Custom handler for the `getSessions(sessionId:)` method.
  package nonisolated(unsafe) var getSessionsHandler: (() async throws -> [Session])?

  /// Custom handler for the `reload()` method.
  package nonisolated(unsafe) var reloadHandler: (() async throws -> User)?

  /// Custom handler for the `update(params:)` method.
  package nonisolated(unsafe) var updateHandler: ((User.UpdateParams) async throws -> User)?

  /// Custom handler for the `createBackupCodes()` method.
  package nonisolated(unsafe) var createBackupCodesHandler: (() async throws -> BackupCodeResource)?

  /// Custom handler for the `createExternalAccount(provider:redirectUrl:additionalScopes:oidcPrompts:)` method.
  package nonisolated(unsafe) var createExternalAccountHandler: ((OAuthProvider, String?, [String], [OIDCPrompt]) async throws -> ExternalAccount)?

  /// Custom handler for the `createExternalAccountToken(provider:idToken:)` method.
  package nonisolated(unsafe) var createExternalAccountTokenHandler: ((IDTokenProvider, String) async throws -> ExternalAccount)?

  /// Custom handler for the `createTotp()` method.
  package nonisolated(unsafe) var createTotpHandler: (() async throws -> TOTPResource)?

  /// Custom handler for the `verifyTotp(code:)` method.
  package nonisolated(unsafe) var verifyTotpHandler: ((String) async throws -> TOTPResource)?

  /// Custom handler for the `disableTotp()` method.
  package nonisolated(unsafe) var disableTotpHandler: (() async throws -> DeletedObject)?

  /// Custom handler for the `getOrganizationInvitations(offset:pageSize:status:)` method.
  ///
  /// The closure receives the pagination arguments plus an optional invitation status filter.
  /// Pass `nil` in tests to simulate no status filter, or a status value such as `"pending"`
  /// to mirror filtered invitation requests.
  package nonisolated(unsafe) var getOrganizationInvitationsHandler: ((Int, Int, String?) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation>)?

  /// Custom handler for the `getOrganizationMemberships(offset:pageSize:)` method.
  package nonisolated(unsafe) var getOrganizationMembershipsHandler: ((Int, Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>)?

  /// Custom handler for the `getOrganizationSuggestions(offset:pageSize:status:)` method.
  ///
  /// The closure receives the pagination arguments plus an array of suggestion status filters.
  /// Pass `[]` in tests to simulate no status filter, or include one or more values such as
  /// `["pending", "accepted"]` to mirror filtered suggestion requests.
  package nonisolated(unsafe) var getOrganizationSuggestionsHandler: ((Int, Int, [String]) async throws -> ClerkPaginatedResponse<OrganizationSuggestion>)?

  /// Custom handler for the `getOrganizationCreationDefaults()` method.
  package nonisolated(unsafe) var getOrganizationCreationDefaultsHandler: (() async throws -> OrganizationCreationDefaults)?

  /// Custom handler for the `updatePassword(params:)` method.
  package nonisolated(unsafe) var updatePasswordHandler: ((User.UpdatePasswordParams) async throws -> User)?

  /// Custom handler for the `setProfileImage(imageData:)` method.
  package nonisolated(unsafe) var setProfileImageHandler: ((Data) async throws -> ImageResource)?

  /// Custom handler for the `deleteProfileImage()` method.
  package nonisolated(unsafe) var deleteProfileImageHandler: (() async throws -> DeletedObject)?

  /// Custom handler for the `delete()` method.
  package nonisolated(unsafe) var deleteHandler: (() async throws -> DeletedObject)?

  /// Creates a new mock user service with named closure parameters matching protocol method names.
  ///
  /// This initializer allows you to configure specific methods inline.
  /// Methods not configured will return default mock values.
  ///
  /// - Parameters:
  ///   - getSessions: Optional implementation of the `getSessions` method with signature `() async throws -> [Session]`.
  ///   - reload: Optional implementation of the `reload()` method.
  ///   - update: Optional implementation of the `update(params:)` method.
  ///   - createBackupCodes: Optional implementation of the `createBackupCodes()` method.
  ///   - createExternalAccount: Optional implementation of the `createExternalAccount(provider:redirectUrl:additionalScopes:oidcPrompts:)` method.
  ///   - createExternalAccountToken: Optional implementation of the `createExternalAccountToken(provider:idToken:)` method.
  ///   - createTotp: Optional implementation of the `createTotp()` method.
  ///   - verifyTotp: Optional implementation of the `verifyTotp(code:)` method.
  ///   - disableTotp: Optional implementation of the `disableTotp()` method.
  ///   - getOrganizationInvitations: Optional implementation of the `getOrganizationInvitations(offset:pageSize:status:)` method
  ///     with signature `((Int, Int, String?) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation>)`.
  ///     The third argument is an optional invitation status filter; pass `nil` to simulate an unfiltered request
  ///     or provide a value such as `"pending"` when a test needs filtered invitations.
  ///   - getOrganizationMemberships: Optional implementation of the `getOrganizationMemberships(offset:pageSize:)` method.
  ///   - getOrganizationSuggestions: Optional implementation of the `getOrganizationSuggestions(offset:pageSize:status:)` method
  ///     with signature `((Int, Int, [String]) async throws -> ClerkPaginatedResponse<OrganizationSuggestion>)`.
  ///     The third argument accepts multiple suggestion statuses; pass `[]` to simulate an unfiltered request
  ///     or provide values such as `["pending", "accepted"]` when a test needs filtered suggestions.
  ///   - getOrganizationCreationDefaults: Optional implementation of the `getOrganizationCreationDefaults()` method.
  ///   - updatePassword: Optional implementation of the `updatePassword(params:)` method.
  ///   - setProfileImage: Optional implementation of the `setProfileImage(imageData:)` method.
  ///   - deleteProfileImage: Optional implementation of the `deleteProfileImage()` method.
  ///   - delete: Optional implementation of the `delete()` method.
  ///
  /// Example:
  /// ```swift
  /// let service = MockUserService(
  ///   getSessions: {
  ///     try? await Task.sleep(for: .seconds(1))
  ///     return [Session.mock, Session.mock2]
  ///   },
  ///   reload: {
  ///     try? await Task.sleep(for: .milliseconds(500))
  ///     return User.mock
  ///   }
  /// )
  /// ```
  package init(
    getSessions: (() async throws -> [Session])? = nil,
    reload: (() async throws -> User)? = nil,
    update: ((User.UpdateParams) async throws -> User)? = nil,
    createBackupCodes: (() async throws -> BackupCodeResource)? = nil,
    createExternalAccount: ((OAuthProvider, String?, [String], [OIDCPrompt]) async throws -> ExternalAccount)? = nil,
    createExternalAccountToken: ((IDTokenProvider, String) async throws -> ExternalAccount)? = nil,
    createTotp: (() async throws -> TOTPResource)? = nil,
    verifyTotp: ((String) async throws -> TOTPResource)? = nil,
    disableTotp: (() async throws -> DeletedObject)? = nil,
    getOrganizationInvitations: ((Int, Int, String?) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation>)? = nil,
    getOrganizationMemberships: ((Int, Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>)? = nil,
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
    createBackupCodesHandler = createBackupCodes
    createExternalAccountHandler = createExternalAccount
    createExternalAccountTokenHandler = createExternalAccountToken
    createTotpHandler = createTotp
    verifyTotpHandler = verifyTotp
    disableTotpHandler = disableTotp
    getOrganizationInvitationsHandler = getOrganizationInvitations
    getOrganizationMembershipsHandler = getOrganizationMemberships
    getOrganizationSuggestionsHandler = getOrganizationSuggestions
    getOrganizationCreationDefaultsHandler = getOrganizationCreationDefaults
    updatePasswordHandler = updatePassword
    setProfileImageHandler = setProfileImage
    deleteProfileImageHandler = deleteProfileImage
    deleteHandler = delete
  }

  @MainActor
  package func reload(sessionId _: String?) async throws -> User {
    if let handler = reloadHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  package func update(params: User.UpdateParams, sessionId _: String?) async throws -> User {
    if let handler = updateHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  package func createBackupCodes(sessionId _: String?) async throws -> BackupCodeResource {
    if let handler = createBackupCodesHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  package func createExternalAccount(
    provider: OAuthProvider,
    redirectUrl: String,
    additionalScopes: [String],
    oidcPrompts: [OIDCPrompt],
    sessionId _: String?
  ) async throws -> ExternalAccount {
    if let handler = createExternalAccountHandler {
      return try await handler(provider, redirectUrl, additionalScopes, oidcPrompts)
    }
    return .mockVerified
  }

  @MainActor
  package func createExternalAccountToken(provider: IDTokenProvider, idToken: String, sessionId _: String?) async throws -> ExternalAccount {
    if let handler = createExternalAccountTokenHandler {
      return try await handler(provider, idToken)
    }
    return .mockVerified
  }

  @MainActor
  package func createTotp(sessionId _: String?) async throws -> TOTPResource {
    if let handler = createTotpHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  package func verifyTotp(code: String, sessionId _: String?) async throws -> TOTPResource {
    if let handler = verifyTotpHandler {
      return try await handler(code)
    }
    return .mock
  }

  @MainActor
  package func disableTotp(sessionId _: String?) async throws -> DeletedObject {
    if let handler = disableTotpHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  package func getOrganizationInvitations(offset: Int, pageSize: Int, status: String?, sessionId _: String?) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> {
    if let handler = getOrganizationInvitationsHandler {
      return try await handler(offset, pageSize, status)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func getOrganizationMemberships(offset: Int, pageSize: Int, sessionId _: String?) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    if let handler = getOrganizationMembershipsHandler {
      return try await handler(offset, pageSize)
    }
    return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
  }

  @MainActor
  package func getOrganizationSuggestions(offset: Int, pageSize: Int, status: [String], sessionId _: String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> {
    if let handler = getOrganizationSuggestionsHandler {
      return try await handler(offset, pageSize, status)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func getOrganizationCreationDefaults(sessionId _: String?) async throws -> OrganizationCreationDefaults {
    if let handler = getOrganizationCreationDefaultsHandler {
      return try await handler()
    }
    return OrganizationCreationDefaults(
      advisory: nil,
      form: .init(name: "My organization", slug: "my-organization", logo: nil, blurHash: nil)
    )
  }

  @MainActor
  package func getSessions(sessionId _: String?) async throws -> [Session] {
    if let handler = getSessionsHandler {
      return try await handler()
    }
    return [.mock, .mock2]
  }

  @MainActor
  package func updatePassword(params: User.UpdatePasswordParams, sessionId _: String?) async throws -> User {
    if let handler = updatePasswordHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  package func setProfileImage(imageData: Data, sessionId _: String?) async throws -> ImageResource {
    if let handler = setProfileImageHandler {
      return try await handler(imageData)
    }
    return ImageResource(id: "mock-image-id", name: "mock-image", publicUrl: nil)
  }

  @MainActor
  package func deleteProfileImage(sessionId _: String?) async throws -> DeletedObject {
    if let handler = deleteProfileImageHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  package func delete(sessionId _: String?) async throws -> DeletedObject {
    if let handler = deleteHandler {
      return try await handler()
    }
    return .mock
  }
}
