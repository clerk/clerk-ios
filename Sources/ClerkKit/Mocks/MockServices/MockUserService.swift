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
public final class MockUserService: UserServiceProtocol {
  /// Custom handler for the `getSessions(user:)` method.
  public nonisolated(unsafe) var getSessionsHandler: ((User) async throws -> [Session])?

  /// Custom handler for the `reload()` method.
  public nonisolated(unsafe) var reloadHandler: (() async throws -> User)?

  /// Custom handler for the `update(params:)` method.
  public nonisolated(unsafe) var updateHandler: ((User.UpdateParams) async throws -> User)?

  /// Custom handler for the `createBackupCodes()` method.
  public nonisolated(unsafe) var createBackupCodesHandler: (() async throws -> BackupCodeResource)?

  /// Custom handler for the `createEmailAddress(emailAddress:)` method.
  public nonisolated(unsafe) var createEmailAddressHandler: ((String) async throws -> EmailAddress)?

  /// Custom handler for the `createPhoneNumber(phoneNumber:)` method.
  public nonisolated(unsafe) var createPhoneNumberHandler: ((String) async throws -> PhoneNumber)?

  /// Custom handler for the `createExternalAccount(provider:redirectUrl:additionalScopes:)` method.
  public nonisolated(unsafe) var createExternalAccountHandler: ((OAuthProvider, String?, [String]?) async throws -> ExternalAccount)?

  /// Custom handler for the `createExternalAccountToken(provider:idToken:)` method.
  public nonisolated(unsafe) var createExternalAccountTokenHandler: ((IDTokenProvider, String) async throws -> ExternalAccount)?

  #if canImport(AuthenticationServices) && !os(watchOS)
  /// Custom handler for the `createPasskey()` method.
  public nonisolated(unsafe) var createPasskeyHandler: (() async throws -> Passkey)?
  #endif

  /// Custom handler for the `createTotp()` method.
  public nonisolated(unsafe) var createTotpHandler: (() async throws -> TOTPResource)?

  /// Custom handler for the `verifyTotp(code:)` method.
  public nonisolated(unsafe) var verifyTotpHandler: ((String) async throws -> TOTPResource)?

  /// Custom handler for the `disableTotp()` method.
  public nonisolated(unsafe) var disableTotpHandler: (() async throws -> DeletedObject)?

  /// Custom handler for the `getOrganizationInvitations(initialPage:pageSize:)` method.
  public nonisolated(unsafe) var getOrganizationInvitationsHandler: ((Int, Int) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation>)?

  /// Custom handler for the `getOrganizationMemberships(initialPage:pageSize:)` method.
  public nonisolated(unsafe) var getOrganizationMembershipsHandler: ((Int, Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>)?

  /// Custom handler for the `getOrganizationSuggestions(initialPage:pageSize:status:)` method.
  public nonisolated(unsafe) var getOrganizationSuggestionsHandler: ((Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion>)?

  /// Custom handler for the `updatePassword(params:)` method.
  public nonisolated(unsafe) var updatePasswordHandler: ((User.UpdatePasswordParams) async throws -> User)?

  /// Custom handler for the `setProfileImage(imageData:)` method.
  public nonisolated(unsafe) var setProfileImageHandler: ((Data) async throws -> ImageResource)?

  /// Custom handler for the `deleteProfileImage()` method.
  public nonisolated(unsafe) var deleteProfileImageHandler: (() async throws -> DeletedObject)?

  /// Custom handler for the `delete()` method.
  public nonisolated(unsafe) var deleteHandler: (() async throws -> DeletedObject)?

  /// Creates a new mock user service with named closure parameters matching protocol method names.
  ///
  /// This initializer allows you to configure specific methods inline.
  /// Methods not configured will return default mock values.
  ///
  /// - Parameters:
  ///   - getSessions: Optional implementation of the `getSessions(user:)` method.
  ///   - reload: Optional implementation of the `reload()` method.
  ///   - update: Optional implementation of the `update(params:)` method.
  ///   - createBackupCodes: Optional implementation of the `createBackupCodes()` method.
  ///   - createEmailAddress: Optional implementation of the `createEmailAddress(emailAddress:)` method.
  ///   - createPhoneNumber: Optional implementation of the `createPhoneNumber(phoneNumber:)` method.
  ///   - createExternalAccount: Optional implementation of the `createExternalAccount(provider:redirectUrl:additionalScopes:)` method.
  ///   - createExternalAccountToken: Optional implementation of the `createExternalAccountToken(provider:idToken:)` method.
  ///   - createPasskey: Optional implementation of the `createPasskey()` method (iOS only).
  ///   - createTotp: Optional implementation of the `createTotp()` method.
  ///   - verifyTotp: Optional implementation of the `verifyTotp(code:)` method.
  ///   - disableTotp: Optional implementation of the `disableTotp()` method.
  ///   - getOrganizationInvitations: Optional implementation of the `getOrganizationInvitations(initialPage:pageSize:)` method.
  ///   - getOrganizationMemberships: Optional implementation of the `getOrganizationMemberships(initialPage:pageSize:)` method.
  ///   - getOrganizationSuggestions: Optional implementation of the `getOrganizationSuggestions(initialPage:pageSize:status:)` method.
  ///   - updatePassword: Optional implementation of the `updatePassword(params:)` method.
  ///   - setProfileImage: Optional implementation of the `setProfileImage(imageData:)` method.
  ///   - deleteProfileImage: Optional implementation of the `deleteProfileImage()` method.
  ///   - delete: Optional implementation of the `delete()` method.
  ///
  /// Example:
  /// ```swift
  /// let service = MockUserService(
  ///   getSessions: { user in
  ///     try? await Task.sleep(for: .seconds(1))
  ///     return [Session.mock, Session.mock2]
  ///   },
  ///   reload: {
  ///     try? await Task.sleep(for: .milliseconds(500))
  ///     return User.mock
  ///   }
  /// )
  /// ```
  public init(
    getSessions: ((User) async throws -> [Session])? = nil,
    reload: (() async throws -> User)? = nil,
    update: ((User.UpdateParams) async throws -> User)? = nil,
    createBackupCodes: (() async throws -> BackupCodeResource)? = nil,
    createEmailAddress: ((String) async throws -> EmailAddress)? = nil,
    createPhoneNumber: ((String) async throws -> PhoneNumber)? = nil,
    createExternalAccount: ((OAuthProvider, String?, [String]?) async throws -> ExternalAccount)? = nil,
    createExternalAccountToken: ((IDTokenProvider, String) async throws -> ExternalAccount)? = nil,
    createTotp: (() async throws -> TOTPResource)? = nil,
    verifyTotp: ((String) async throws -> TOTPResource)? = nil,
    disableTotp: (() async throws -> DeletedObject)? = nil,
    getOrganizationInvitations: ((Int, Int) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation>)? = nil,
    getOrganizationMemberships: ((Int, Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>)? = nil,
    getOrganizationSuggestions: ((Int, Int, String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion>)? = nil,
    updatePassword: ((User.UpdatePasswordParams) async throws -> User)? = nil,
    setProfileImage: ((Data) async throws -> ImageResource)? = nil,
    deleteProfileImage: (() async throws -> DeletedObject)? = nil,
    delete: (() async throws -> DeletedObject)? = nil
  ) {
    getSessionsHandler = getSessions
    reloadHandler = reload
    updateHandler = update
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
    getOrganizationSuggestionsHandler = getOrganizationSuggestions
    updatePasswordHandler = updatePassword
    setProfileImageHandler = setProfileImage
    deleteProfileImageHandler = deleteProfileImage
    deleteHandler = delete
  }

  #if canImport(AuthenticationServices) && !os(watchOS)
  /// Sets the `createPasskey` handler for this mock service.
  ///
  /// - Parameter createPasskey: The implementation of the `createPasskey()` method.
  public func setCreatePasskey(_ createPasskey: @escaping () async throws -> Passkey) {
    createPasskeyHandler = createPasskey
  }
  #endif

  @MainActor
  public func reload() async throws -> User {
    if let handler = reloadHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  public func update(params: User.UpdateParams) async throws -> User {
    if let handler = updateHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  public func createBackupCodes() async throws -> BackupCodeResource {
    if let handler = createBackupCodesHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  public func createEmailAddress(emailAddress: String) async throws -> EmailAddress {
    if let handler = createEmailAddressHandler {
      return try await handler(emailAddress)
    }
    return .mock
  }

  @MainActor
  public func createPhoneNumber(phoneNumber: String) async throws -> PhoneNumber {
    if let handler = createPhoneNumberHandler {
      return try await handler(phoneNumber)
    }
    return .mock
  }

  @MainActor
  public func createExternalAccount(provider: OAuthProvider, redirectUrl: String?, additionalScopes: [String]?) async throws -> ExternalAccount {
    if let handler = createExternalAccountHandler {
      return try await handler(provider, redirectUrl, additionalScopes)
    }
    return .mockVerified
  }

  @MainActor
  public func createExternalAccountToken(provider: IDTokenProvider, idToken: String) async throws -> ExternalAccount {
    if let handler = createExternalAccountTokenHandler {
      return try await handler(provider, idToken)
    }
    return .mockVerified
  }

  #if canImport(AuthenticationServices) && !os(watchOS)
  @MainActor
  public func createPasskey() async throws -> Passkey {
    if let handler = createPasskeyHandler {
      return try await handler()
    }
    return .mock
  }
  #endif

  @MainActor
  public func createTotp() async throws -> TOTPResource {
    if let handler = createTotpHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  public func verifyTotp(code: String) async throws -> TOTPResource {
    if let handler = verifyTotpHandler {
      return try await handler(code)
    }
    return .mock
  }

  @MainActor
  public func disableTotp() async throws -> DeletedObject {
    if let handler = disableTotpHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  public func getOrganizationInvitations(initialPage: Int, pageSize: Int) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> {
    if let handler = getOrganizationInvitationsHandler {
      return try await handler(initialPage, pageSize)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  public func getOrganizationMemberships(initialPage: Int, pageSize: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    if let handler = getOrganizationMembershipsHandler {
      return try await handler(initialPage, pageSize)
    }
    return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
  }

  @MainActor
  public func getOrganizationSuggestions(initialPage: Int, pageSize: Int, status: String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> {
    if let handler = getOrganizationSuggestionsHandler {
      return try await handler(initialPage, pageSize, status)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  public func getSessions(user: User) async throws -> [Session] {
    if let handler = getSessionsHandler {
      return try await handler(user)
    }
    return [.mock, .mock2]
  }

  @MainActor
  public func updatePassword(params: User.UpdatePasswordParams) async throws -> User {
    if let handler = updatePasswordHandler {
      return try await handler(params)
    }
    return .mock
  }

  @MainActor
  public func setProfileImage(imageData: Data) async throws -> ImageResource {
    if let handler = setProfileImageHandler {
      return try await handler(imageData)
    }
    return ImageResource(id: "mock-image-id", name: "mock-image", publicUrl: nil)
  }

  @MainActor
  public func deleteProfileImage() async throws -> DeletedObject {
    if let handler = deleteProfileImageHandler {
      return try await handler()
    }
    return .mock
  }

  @MainActor
  public func delete() async throws -> DeletedObject {
    if let handler = deleteHandler {
      return try await handler()
    }
    return .mock
  }
}
