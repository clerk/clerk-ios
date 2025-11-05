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
/// All methods must be explicitly configured in the initializer or they will fatalError if called.
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
  /// Methods not configured will fatalError if called.
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
    self.getSessionsHandler = getSessions
    self.reloadHandler = reload
    self.updateHandler = update
    self.createBackupCodesHandler = createBackupCodes
    self.createEmailAddressHandler = createEmailAddress
    self.createPhoneNumberHandler = createPhoneNumber
    self.createExternalAccountHandler = createExternalAccount
    self.createExternalAccountTokenHandler = createExternalAccountToken
    self.createTotpHandler = createTotp
    self.verifyTotpHandler = verifyTotp
    self.disableTotpHandler = disableTotp
    self.getOrganizationInvitationsHandler = getOrganizationInvitations
    self.getOrganizationMembershipsHandler = getOrganizationMemberships
    self.getOrganizationSuggestionsHandler = getOrganizationSuggestions
    self.updatePasswordHandler = updatePassword
    self.setProfileImageHandler = setProfileImage
    self.deleteProfileImageHandler = deleteProfileImage
    self.deleteHandler = delete
  }

  #if canImport(AuthenticationServices) && !os(watchOS)
  /// Sets the `createPasskey` handler for this mock service.
  ///
  /// - Parameter createPasskey: The implementation of the `createPasskey()` method.
  public func setCreatePasskey(_ createPasskey: @escaping () async throws -> Passkey) {
    self.createPasskeyHandler = createPasskey
  }
  #endif

  @MainActor
  public func reload() async throws -> User {
    guard let handler = reloadHandler else {
      fatalError("MockUserService.reload() was called but not configured. Provide a reload: parameter in the initializer.")
    }
    return try await handler()
  }

  @MainActor
  public func update(params: User.UpdateParams) async throws -> User {
    guard let handler = updateHandler else {
      fatalError("MockUserService.update(params:) was called but not configured. Provide an update: parameter in the initializer.")
    }
    return try await handler(params)
  }

  @MainActor
  public func createBackupCodes() async throws -> BackupCodeResource {
    guard let handler = createBackupCodesHandler else {
      fatalError("MockUserService.createBackupCodes() was called but not configured. Provide a createBackupCodes: parameter in the initializer.")
    }
    return try await handler()
  }

  @MainActor
  public func createEmailAddress(emailAddress: String) async throws -> EmailAddress {
    guard let handler = createEmailAddressHandler else {
      fatalError("MockUserService.createEmailAddress(emailAddress:) was called but not configured. Provide a createEmailAddress: parameter in the initializer.")
    }
    return try await handler(emailAddress)
  }

  @MainActor
  public func createPhoneNumber(phoneNumber: String) async throws -> PhoneNumber {
    guard let handler = createPhoneNumberHandler else {
      fatalError("MockUserService.createPhoneNumber(phoneNumber:) was called but not configured. Provide a createPhoneNumber: parameter in the initializer.")
    }
    return try await handler(phoneNumber)
  }

  @MainActor
  public func createExternalAccount(provider: OAuthProvider, redirectUrl: String?, additionalScopes: [String]?) async throws -> ExternalAccount {
    guard let handler = createExternalAccountHandler else {
      fatalError("MockUserService.createExternalAccount(provider:redirectUrl:additionalScopes:) was called but not configured. Provide a createExternalAccount: parameter in the initializer.")
    }
    return try await handler(provider, redirectUrl, additionalScopes)
  }

  @MainActor
  public func createExternalAccountToken(provider: IDTokenProvider, idToken: String) async throws -> ExternalAccount {
    guard let handler = createExternalAccountTokenHandler else {
      fatalError("MockUserService.createExternalAccountToken(provider:idToken:) was called but not configured. Provide a createExternalAccountToken: parameter in the initializer.")
    }
    return try await handler(provider, idToken)
  }

  #if canImport(AuthenticationServices) && !os(watchOS)
  @MainActor
  public func createPasskey() async throws -> Passkey {
    guard let handler = createPasskeyHandler else {
      fatalError("MockUserService.createPasskey() was called but not configured. Provide a createPasskey: parameter in the initializer.")
    }
    return try await handler()
  }
  #endif

  @MainActor
  public func createTotp() async throws -> TOTPResource {
    guard let handler = createTotpHandler else {
      fatalError("MockUserService.createTotp() was called but not configured. Provide a createTotp: parameter in the initializer.")
    }
    return try await handler()
  }

  @MainActor
  public func verifyTotp(code: String) async throws -> TOTPResource {
    guard let handler = verifyTotpHandler else {
      fatalError("MockUserService.verifyTotp(code:) was called but not configured. Provide a verifyTotp: parameter in the initializer.")
    }
    return try await handler(code)
  }

  @MainActor
  public func disableTotp() async throws -> DeletedObject {
    guard let handler = disableTotpHandler else {
      fatalError("MockUserService.disableTotp() was called but not configured. Provide a disableTotp: parameter in the initializer.")
    }
    return try await handler()
  }

  @MainActor
  public func getOrganizationInvitations(initialPage: Int, pageSize: Int) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> {
    guard let handler = getOrganizationInvitationsHandler else {
      fatalError("MockUserService.getOrganizationInvitations(initialPage:pageSize:) was called but not configured. Provide a getOrganizationInvitations: parameter in the initializer.")
    }
    return try await handler(initialPage, pageSize)
  }

  @MainActor
  public func getOrganizationMemberships(initialPage: Int, pageSize: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    guard let handler = getOrganizationMembershipsHandler else {
      fatalError("MockUserService.getOrganizationMemberships(initialPage:pageSize:) was called but not configured. Provide a getOrganizationMemberships: parameter in the initializer.")
    }
    return try await handler(initialPage, pageSize)
  }

  @MainActor
  public func getOrganizationSuggestions(initialPage: Int, pageSize: Int, status: String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> {
    guard let handler = getOrganizationSuggestionsHandler else {
      fatalError("MockUserService.getOrganizationSuggestions(initialPage:pageSize:status:) was called but not configured. Provide a getOrganizationSuggestions: parameter in the initializer.")
    }
    return try await handler(initialPage, pageSize, status)
  }

  @MainActor
  public func getSessions(user: User) async throws -> [Session] {
    guard let handler = getSessionsHandler else {
      fatalError("MockUserService.getSessions(user:) was called but not configured. Provide a getSessions: parameter in the initializer.")
    }
    return try await handler(user)
  }

  @MainActor
  public func updatePassword(params: User.UpdatePasswordParams) async throws -> User {
    guard let handler = updatePasswordHandler else {
      fatalError("MockUserService.updatePassword(params:) was called but not configured. Provide an updatePassword: parameter in the initializer.")
    }
    return try await handler(params)
  }

  @MainActor
  public func setProfileImage(imageData: Data) async throws -> ImageResource {
    guard let handler = setProfileImageHandler else {
      fatalError("MockUserService.setProfileImage(imageData:) was called but not configured. Provide a setProfileImage: parameter in the initializer.")
    }
    return try await handler(imageData)
  }

  @MainActor
  public func deleteProfileImage() async throws -> DeletedObject {
    guard let handler = deleteProfileImageHandler else {
      fatalError("MockUserService.deleteProfileImage() was called but not configured. Provide a deleteProfileImage: parameter in the initializer.")
    }
    return try await handler()
  }

  @MainActor
  public func delete() async throws -> DeletedObject {
    guard let handler = deleteHandler else {
      fatalError("MockUserService.delete() was called but not configured. Provide a delete: parameter in the initializer.")
    }
    return try await handler()
  }
}

