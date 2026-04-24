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
  package nonisolated(unsafe) var getSessionsHandler: ((String?) async throws -> [Session])?

  /// Custom handler for the `reload(sessionId:)` method.
  package nonisolated(unsafe) var reloadHandler: ((String?) async throws -> User)?

  /// Custom handler for the `update(params:sessionId:)` method.
  package nonisolated(unsafe) var updateHandler: ((User.UpdateParams, String?) async throws -> User)?

  /// Custom handler for the `createBackupCodes(sessionId:)` method.
  package nonisolated(unsafe) var createBackupCodesHandler: ((String?) async throws -> BackupCodeResource)?

  /// Custom handler for the `createExternalAccount(provider:redirectUrl:additionalScopes:oidcPrompts:sessionId:)` method.
  package nonisolated(unsafe) var createExternalAccountHandler: ((OAuthProvider, String?, [String], [OIDCPrompt], String?) async throws -> ExternalAccount)?

  /// Custom handler for the `createExternalAccountToken(provider:idToken:sessionId:)` method.
  package nonisolated(unsafe) var createExternalAccountTokenHandler: ((IDTokenProvider, String, String?) async throws -> ExternalAccount)?

  /// Custom handler for the `createTotp(sessionId:)` method.
  package nonisolated(unsafe) var createTotpHandler: ((String?) async throws -> TOTPResource)?

  /// Custom handler for the `verifyTotp(code:sessionId:)` method.
  package nonisolated(unsafe) var verifyTotpHandler: ((String, String?) async throws -> TOTPResource)?

  /// Custom handler for the `disableTotp(sessionId:)` method.
  package nonisolated(unsafe) var disableTotpHandler: ((String?) async throws -> DeletedObject)?

  /// Custom handler for the `getOrganizationInvitations(offset:pageSize:status:sessionId:)` method.
  ///
  /// The closure receives the pagination arguments, an optional invitation status filter, and the session ID.
  /// Pass `nil` in tests to simulate no status filter, or a status value such as `"pending"`
  /// to mirror filtered invitation requests.
  package nonisolated(unsafe) var getOrganizationInvitationsHandler: ((Int, Int, String?, String?) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation>)?

  /// Custom handler for the `getOrganizationMemberships(offset:pageSize:sessionId:)` method.
  package nonisolated(unsafe) var getOrganizationMembershipsHandler: ((Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationMembership>)?

  /// Custom handler for the `getOrganizationSuggestions(offset:pageSize:status:sessionId:)` method.
  ///
  /// The closure receives the pagination arguments, an array of suggestion status filters, and the session ID.
  /// Pass `[]` in tests to simulate no status filter, or include one or more values such as
  /// `["pending", "accepted"]` to mirror filtered suggestion requests.
  package nonisolated(unsafe) var getOrganizationSuggestionsHandler: ((Int, Int, [String], String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion>)?

  /// Custom handler for the `getOrganizationCreationDefaults(sessionId:)` method.
  package nonisolated(unsafe) var getOrganizationCreationDefaultsHandler: ((String?) async throws -> OrganizationCreationDefaults)?

  /// Custom handler for the `updatePassword(params:sessionId:)` method.
  package nonisolated(unsafe) var updatePasswordHandler: ((User.UpdatePasswordParams, String?) async throws -> User)?

  /// Custom handler for the `setProfileImage(imageData:sessionId:)` method.
  package nonisolated(unsafe) var setProfileImageHandler: ((Data, String?) async throws -> ImageResource)?

  /// Custom handler for the `deleteProfileImage(sessionId:)` method.
  package nonisolated(unsafe) var deleteProfileImageHandler: ((String?) async throws -> DeletedObject)?

  /// Custom handler for the `delete(sessionId:)` method.
  package nonisolated(unsafe) var deleteHandler: ((String?) async throws -> DeletedObject)?

  /// Creates a new mock user service with named closure parameters matching protocol method names.
  ///
  /// This initializer allows you to configure specific methods inline.
  /// Methods not configured will return default mock values.
  ///
  /// - Parameters:
  ///   - getSessions: Optional implementation of the `getSessions(sessionId:)` method.
  ///   - reload: Optional implementation of the `reload(sessionId:)` method.
  ///   - update: Optional implementation of the `update(params:sessionId:)` method.
  ///   - createBackupCodes: Optional implementation of the `createBackupCodes(sessionId:)` method.
  ///   - createExternalAccount: Optional implementation of the `createExternalAccount(provider:redirectUrl:additionalScopes:oidcPrompts:sessionId:)` method.
  ///   - createExternalAccountToken: Optional implementation of the `createExternalAccountToken(provider:idToken:sessionId:)` method.
  ///   - createTotp: Optional implementation of the `createTotp(sessionId:)` method.
  ///   - verifyTotp: Optional implementation of the `verifyTotp(code:sessionId:)` method.
  ///   - disableTotp: Optional implementation of the `disableTotp(sessionId:)` method.
  ///   - getOrganizationInvitations: Optional implementation of the `getOrganizationInvitations(offset:pageSize:status:sessionId:)` method
  ///     with signature `((Int, Int, String?, String?) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation>)`.
  ///     The third argument is an optional invitation status filter, and the fourth is the session ID.
  ///     Pass `nil` to simulate an unfiltered request or provide a value such as `"pending"`
  ///     when a test needs filtered invitations.
  ///   - getOrganizationMemberships: Optional implementation of the `getOrganizationMemberships(offset:pageSize:sessionId:)` method.
  ///   - getOrganizationSuggestions: Optional implementation of the `getOrganizationSuggestions(offset:pageSize:status:sessionId:)` method
  ///     with signature `((Int, Int, [String], String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion>)`.
  ///     The third argument accepts multiple suggestion statuses, and the fourth is the session ID.
  ///     Pass `[]` to simulate an unfiltered request or provide values such as `["pending", "accepted"]`
  ///     when a test needs filtered suggestions.
  ///   - getOrganizationCreationDefaults: Optional implementation of the `getOrganizationCreationDefaults(sessionId:)` method.
  ///   - updatePassword: Optional implementation of the `updatePassword(params:sessionId:)` method.
  ///   - setProfileImage: Optional implementation of the `setProfileImage(imageData:sessionId:)` method.
  ///   - deleteProfileImage: Optional implementation of the `deleteProfileImage(sessionId:)` method.
  ///   - delete: Optional implementation of the `delete(sessionId:)` method.
  ///
  /// Example:
  /// ```swift
  /// let service = MockUserService(
  ///   getSessions: { _ in
  ///     try? await Task.sleep(for: .seconds(1))
  ///     return [Session.mock, Session.mock2]
  ///   },
  ///   reload: { _ in
  ///     try? await Task.sleep(for: .milliseconds(500))
  ///     return User.mock
  ///   }
  /// )
  /// ```
  package init(
    getSessions: ((String?) async throws -> [Session])? = nil,
    reload: ((String?) async throws -> User)? = nil,
    update: ((User.UpdateParams, String?) async throws -> User)? = nil,
    createBackupCodes: ((String?) async throws -> BackupCodeResource)? = nil,
    createExternalAccount: ((OAuthProvider, String?, [String], [OIDCPrompt], String?) async throws -> ExternalAccount)? = nil,
    createExternalAccountToken: ((IDTokenProvider, String, String?) async throws -> ExternalAccount)? = nil,
    createTotp: ((String?) async throws -> TOTPResource)? = nil,
    verifyTotp: ((String, String?) async throws -> TOTPResource)? = nil,
    disableTotp: ((String?) async throws -> DeletedObject)? = nil,
    getOrganizationInvitations: ((Int, Int, String?, String?) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation>)? = nil,
    getOrganizationMemberships: ((Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationMembership>)? = nil,
    getOrganizationSuggestions: ((Int, Int, [String], String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion>)? = nil,
    getOrganizationCreationDefaults: ((String?) async throws -> OrganizationCreationDefaults)? = nil,
    updatePassword: ((User.UpdatePasswordParams, String?) async throws -> User)? = nil,
    setProfileImage: ((Data, String?) async throws -> ImageResource)? = nil,
    deleteProfileImage: ((String?) async throws -> DeletedObject)? = nil,
    delete: ((String?) async throws -> DeletedObject)? = nil
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
  package func reload(sessionId: String?) async throws -> User {
    if let handler = reloadHandler {
      return try await handler(sessionId)
    }
    return .mock
  }

  @MainActor
  package func update(params: User.UpdateParams, sessionId: String?) async throws -> User {
    if let handler = updateHandler {
      return try await handler(params, sessionId)
    }
    return .mock
  }

  @MainActor
  package func createBackupCodes(sessionId: String?) async throws -> BackupCodeResource {
    if let handler = createBackupCodesHandler {
      return try await handler(sessionId)
    }
    return .mock
  }

  @MainActor
  package func createExternalAccount(
    provider: OAuthProvider,
    redirectUrl: String,
    additionalScopes: [String],
    oidcPrompts: [OIDCPrompt],
    sessionId: String?
  ) async throws -> ExternalAccount {
    if let handler = createExternalAccountHandler {
      return try await handler(provider, redirectUrl, additionalScopes, oidcPrompts, sessionId)
    }
    return .mockVerified
  }

  @MainActor
  package func createExternalAccountToken(provider: IDTokenProvider, idToken: String, sessionId: String?) async throws -> ExternalAccount {
    if let handler = createExternalAccountTokenHandler {
      return try await handler(provider, idToken, sessionId)
    }
    return .mockVerified
  }

  @MainActor
  package func createTotp(sessionId: String?) async throws -> TOTPResource {
    if let handler = createTotpHandler {
      return try await handler(sessionId)
    }
    return .mock
  }

  @MainActor
  package func verifyTotp(code: String, sessionId: String?) async throws -> TOTPResource {
    if let handler = verifyTotpHandler {
      return try await handler(code, sessionId)
    }
    return .mock
  }

  @MainActor
  package func disableTotp(sessionId: String?) async throws -> DeletedObject {
    if let handler = disableTotpHandler {
      return try await handler(sessionId)
    }
    return .mock
  }

  @MainActor
  package func getOrganizationInvitations(offset: Int, pageSize: Int, status: String?, sessionId: String?) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> {
    if let handler = getOrganizationInvitationsHandler {
      return try await handler(offset, pageSize, status, sessionId)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func getOrganizationMemberships(offset: Int, pageSize: Int, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    if let handler = getOrganizationMembershipsHandler {
      return try await handler(offset, pageSize, sessionId)
    }
    return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
  }

  @MainActor
  package func getOrganizationSuggestions(offset: Int, pageSize: Int, status: [String], sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> {
    if let handler = getOrganizationSuggestionsHandler {
      return try await handler(offset, pageSize, status, sessionId)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func getOrganizationCreationDefaults(sessionId: String?) async throws -> OrganizationCreationDefaults {
    if let handler = getOrganizationCreationDefaultsHandler {
      return try await handler(sessionId)
    }
    return OrganizationCreationDefaults(
      advisory: nil,
      form: .init(name: "My organization", slug: "my-organization", logo: nil, blurHash: nil)
    )
  }

  @MainActor
  package func getSessions(sessionId: String?) async throws -> [Session] {
    if let handler = getSessionsHandler {
      return try await handler(sessionId)
    }
    return [.mock, .mock2]
  }

  @MainActor
  package func updatePassword(params: User.UpdatePasswordParams, sessionId: String?) async throws -> User {
    if let handler = updatePasswordHandler {
      return try await handler(params, sessionId)
    }
    return .mock
  }

  @MainActor
  package func setProfileImage(imageData: Data, sessionId: String?) async throws -> ImageResource {
    if let handler = setProfileImageHandler {
      return try await handler(imageData, sessionId)
    }
    return ImageResource(id: "mock-image-id", name: "mock-image", publicUrl: nil)
  }

  @MainActor
  package func deleteProfileImage(sessionId: String?) async throws -> DeletedObject {
    if let handler = deleteProfileImageHandler {
      return try await handler(sessionId)
    }
    return .mock
  }

  @MainActor
  package func delete(sessionId: String?) async throws -> DeletedObject {
    if let handler = deleteHandler {
      return try await handler(sessionId)
    }
    return .mock
  }
}
