//
//  User.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

import Foundation

/// The `User` object holds all of the information for a single user of your application and provides a set of methods to manage their account.
///
/// Each user has a unique authentication identifier which might be their email address, phone number, or a username.
///
/// A user can be contacted at their primary email address or primary phone number. They can have more than one registered email address,
/// but only one of them will be their primary email address. This goes for phone numbers as well; a user can have more than one,
/// but only one phone number will be their primary. At the same time, a user can also have one or more external accounts by connecting
/// to social providers such as Google, Apple, Facebook, and many more.
///
/// Finally, a `User` object holds profile data like the user's name, profile picture, and a set of metadata that can be used internally
/// to store arbitrary information. The metadata are split into `publicMetadata` and `privateMetadata`. Both types are set from the
/// Backend API, but public metadata can also be accessed from the Frontend API.
///
/// The Clerk iOS SDK provides some helper methods on the User object to help retrieve and update user information and authentication status.
public struct User: Codable, Equatable, Sendable, Hashable, Identifiable {
  public var backupCodeEnabled: Bool

  /// Date when the user was first created.
  public var createdAt: Date

  /// A boolean indicating whether the organization creation is enabled for the user or not.
  public var createOrganizationEnabled: Bool

  /// An integer indicating the number of organizations that can be created by the user. If the value is 0, then the user can create unlimited organizations. Default is null.
  public var createOrganizationsLimit: Int?

  /// A boolean indicating whether the user is able to delete their own account or not.
  public var deleteSelfEnabled: Bool

  /// An array of all the EmailAddress objects associated with the user. Includes the primary.
  public var emailAddresses: [EmailAddress]

  /// A list of enterprise accounts associated with the user.
  public var enterpriseAccounts: [EnterpriseAccount]?

  /// An array of all the ExternalAccount objects associated with the user via OAuth. Note: This includes both verified & unverified external accounts.
  public var externalAccounts: [ExternalAccount]

  /// The user's first name.
  public var firstName: String?

  /// A getter boolean to check if the user has uploaded an image or one was copied from OAuth. Returns false if Clerk is displaying an avatar for the user.
  public var hasImage: Bool

  /// A getter boolean to check if the user has verified an email address.
  public var hasVerifiedEmailAddress: Bool {
    emailAddresses.contains { emailAddress in
      emailAddress.verification?.status == .verified
    }
  }

  /// A getter boolean to check if the user has verified a phone number.
  public var hasVerifiedPhoneNumber: Bool {
    phoneNumbers.contains { phoneNumber in
      phoneNumber.verification?.status == .verified
    }
  }

  /// The unique identifier for the user.
  public var id: String

  /// Holds the default avatar or user's uploaded profile image
  public var imageUrl: String

  /// Date when the user last signed in. May be empty if the user has never signed in.
  public var lastSignInAt: Date?

  /// The user's last name.
  public var lastName: String?

  /// The date on which the user accepted the legal requirements if required.
  public var legalAcceptedAt: Date?

  /// A list of OrganizationMemberships representing the list of organizations the user is member with.
  public var organizationMemberships: [OrganizationMembership]?

  /// An array of all the Passkey objects associated with the user.
  public var passkeys: [Passkey]

  /// A boolean indicating whether the user has a password on their account.
  public var passwordEnabled: Bool

  /// An array of all the PhoneNumber objects associated with the user. Includes the primary.
  public var phoneNumbers: [PhoneNumber]

  /// Information about the user's primary email address.
  public var primaryEmailAddress: EmailAddress? {
    emailAddresses.first(where: { $0.id == primaryEmailAddressId })
  }

  /// The unique identifier for the EmailAddress that the user has set as primary.
  public var primaryEmailAddressId: String?

  /// Information about the user's primary phone number.
  public var primaryPhoneNumber: PhoneNumber? {
    phoneNumbers.first(where: { $0.id == primaryPhoneNumberId })
  }

  /// The unique identifier for the PhoneNumber that the user has set as primary.
  public var primaryPhoneNumberId: String?

  /// Metadata that can be read from the Frontend API and Backend API and can be set only from the Backend API .
  public var publicMetadata: JSON?

  /// A boolean indicating whether the user has enabled TOTP by generating a TOTP secret and verifying it via an authenticator app.
  public var totpEnabled: Bool

  /// A boolean indicating whether the user has enabled two-factor authentication.
  public var twoFactorEnabled: Bool

  /// Date of the last time the user was updated.
  public var updatedAt: Date

  /**
   Metadata that can be read and set from the Frontend API. One common use case for this attribute is to implement custom fields that will be attached to the User object.
   Please note that there is also an unsafeMetadata attribute in the SignUp object. The value of that field will be automatically copied to the user's unsafe metadata once the sign up is complete.
   */
  public var unsafeMetadata: JSON?

  /// A getter for the user's list of unverified external accounts.
  public var unverifiedExternalAccounts: [ExternalAccount] {
    externalAccounts.filter { externalAccount in
      externalAccount.verification?.status == .unverified
    }
  }

  /// The user's username.
  public var username: String?

  /// A getter for the user's list of verified external accounts.
  public var verifiedExternalAccounts: [ExternalAccount] {
    externalAccounts.filter { externalAccount in
      externalAccount.verification?.status == .verified
    }
  }

  public init(
    backupCodeEnabled: Bool,
    createdAt: Date,
    createOrganizationEnabled: Bool,
    createOrganizationsLimit: Int? = nil,
    deleteSelfEnabled: Bool,
    emailAddresses: [EmailAddress],
    enterpriseAccounts: [EnterpriseAccount]? = nil,
    externalAccounts: [ExternalAccount],
    firstName: String? = nil,
    hasImage: Bool,
    id: String,
    imageUrl: String,
    lastSignInAt: Date? = nil,
    lastName: String? = nil,
    legalAcceptedAt: Date? = nil,
    organizationMemberships: [OrganizationMembership]?,
    passkeys: [Passkey],
    passwordEnabled: Bool,
    phoneNumbers: [PhoneNumber],
    primaryEmailAddressId: String? = nil,
    primaryPhoneNumberId: String? = nil,
    publicMetadata: JSON? = nil,
    totpEnabled: Bool,
    twoFactorEnabled: Bool,
    updatedAt: Date,
    unsafeMetadata: JSON? = nil,
    username: String? = nil
  ) {
    self.backupCodeEnabled = backupCodeEnabled
    self.createdAt = createdAt
    self.createOrganizationEnabled = createOrganizationEnabled
    self.createOrganizationsLimit = createOrganizationsLimit
    self.deleteSelfEnabled = deleteSelfEnabled
    self.emailAddresses = emailAddresses
    self.enterpriseAccounts = enterpriseAccounts
    self.externalAccounts = externalAccounts
    self.firstName = firstName
    self.hasImage = hasImage
    self.id = id
    self.imageUrl = imageUrl
    self.lastSignInAt = lastSignInAt
    self.lastName = lastName
    self.legalAcceptedAt = legalAcceptedAt
    self.organizationMemberships = organizationMemberships
    self.passkeys = passkeys
    self.passwordEnabled = passwordEnabled
    self.phoneNumbers = phoneNumbers
    self.primaryEmailAddressId = primaryEmailAddressId
    self.primaryPhoneNumberId = primaryPhoneNumberId
    self.publicMetadata = publicMetadata
    self.totpEnabled = totpEnabled
    self.twoFactorEnabled = twoFactorEnabled
    self.updatedAt = updatedAt
    self.unsafeMetadata = unsafeMetadata
    self.username = username
  }
}

public extension User {
  @MainActor
  private var userService: any UserServiceProtocol { Clerk.shared.dependencies.userService }

  /// Reloads the user from the Clerk API.
  @discardableResult @MainActor
  func reload() async throws -> User {
    try await userService.reload()
  }

  /// Updates the user's attributes. Use this method to save information you collected about the user.
  ///
  /// The appropriate settings must be enabled in the Clerk Dashboard for the user to be able to update their attributes.
  ///
  /// For example, if you want to use the `update(.init(firstName:))` method, you must enable the Name setting.
  /// It can be found in the Email, phone, username > Personal information section in the Clerk Dashboard.
  @discardableResult @MainActor
  func update(_ params: User.UpdateParams) async throws -> User {
    try await userService.update(params: params)
  }

  /// Generates a fresh new set of backup codes for the user. Every time the method is called, it will replace the previously generated backup codes.
  ///
  /// - Returns: ``BackupCodeResource``
  @discardableResult @MainActor
  func createBackupCodes() async throws -> BackupCodeResource {
    try await userService.createBackupCodes()
  }

  /// Adds an email address for the user. A new EmailAddress will be created and associated with the user.
  /// - Parameter email: The value of the email address.
  @discardableResult @MainActor
  func createEmailAddress(_ emailAddress: String) async throws -> EmailAddress {
    try await userService.createEmailAddress(emailAddress: emailAddress)
  }

  /// Adds a phone number for the user. A new PhoneNumber will be created and associated with the user.
  /// - Parameter phoneNumber: The value of the phone number, in E.164 format.
  @discardableResult @MainActor
  func createPhoneNumber(_ phoneNumber: String) async throws -> PhoneNumber {
    try await userService.createPhoneNumber(phoneNumber: phoneNumber)
  }

  /// Adds an external account for the user. A new ExternalAccount will be created and associated with the user.
  ///
  /// This method is useful if you want to allow an already signed-in user to connect their account with an external OAuth provider, such as Facebook, GitHub, etc., so that they can sign in with that provider in the future.
  /// - Parameters:
  ///    - provider: The OAuth provider. For example: `.facebook`, `.github`, etc.
  ///    - redirectUrl: The full URL or path that the OAuth provider should redirect to, on successful authorization on their part.
  ///    - additionalScopes: Additional scopes for your user to be prompted to approve.
  @discardableResult @MainActor
  func createExternalAccount(provider: OAuthProvider, redirectUrl: String? = nil, additionalScopes: [String]? = nil) async throws -> ExternalAccount {
    try await userService.createExternalAccount(provider: provider, redirectUrl: redirectUrl, additionalScopes: additionalScopes)
  }

  /// Adds an external account for the user. A new ExternalAccount will be created and associated with the user.
  ///
  /// This method is useful if you want to allow an already signed-in user to connect their account with an external provider using an ID token provider, such as Apple, etc., so that they can sign in with that provider in the future.
  /// - Parameters:
  ///     - provider: The IDTokenProvider. For example: `.apple`.
  ///     - idToken: The ID token from the provider.
  @discardableResult @MainActor
  func createExternalAccount(provider: IDTokenProvider, idToken: String) async throws -> ExternalAccount {
    try await userService.createExternalAccountToken(provider: provider, idToken: idToken)
  }

  #if canImport(AuthenticationServices) && !os(watchOS)
  /// Creates a passkey for the signed-in user.
  ///
  /// - Returns: ``Passkey``
  @discardableResult @MainActor
  func createPasskey() async throws -> Passkey {
    try await userService.createPasskey()
  }
  #endif

  /// Generates a TOTP secret for a user that can be used to register the application on the user's authenticator app of choice.
  ///
  /// Note that if this method is called again (while still unverified), it replaces the previously generated secret.
  @discardableResult @MainActor
  func createTOTP() async throws -> TOTPResource {
    try await userService.createTotp()
  }

  /// Verifies a TOTP secret after a user has created it.
  ///
  /// The user must provide a code from their authenticator app, that has been generated using the previously created secret.
  /// This way, correct set up and ownership of the authenticator app can be validated.
  /// - Parameter code: A 6 digit TOTP generated from the user's authenticator app.
  @discardableResult @MainActor
  func verifyTOTP(code: String) async throws -> TOTPResource {
    try await userService.verifyTotp(code: code)
  }

  /// Disables TOTP by deleting the user's TOTP secret.
  @discardableResult @MainActor
  func disableTOTP() async throws -> DeletedObject {
    try await userService.disableTotp()
  }

  /// Retrieves a list of organization invitations for the user.
  /// - Parameters:
  ///   - initialPage: A number that can be used to skip the first n-1 pages. For example, if initialPage is set to 10, it is will skip the first 9 pages and will fetch the 10th page.
  ///   - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
  /// - Returns: A ``ClerkPaginatedResponse`` of ``UserOrganizationInvitation`` objects.
  @discardableResult @MainActor
  func getOrganizationInvitations(
    initialPage: Int = 0,
    pageSize: Int = 20
  ) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> {
    try await userService.getOrganizationInvitations(initialPage: initialPage, pageSize: pageSize)
  }

  /// Retrieves a list of organization memberships for the user.
  /// - Parameters:
  ///   - initialPage: A number that can be used to skip the first n-1 pages. For example, if initialPage is set to 10, it is will skip the first 9 pages and will fetch the 10th page.
  ///   - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
  /// - Returns: A ``ClerkPaginatedResponse`` of ``OrganizationMembership`` objects.
  @discardableResult @MainActor
  func getOrganizationMemberships(
    initialPage: Int = 0,
    pageSize: Int = 20
  ) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    try await userService.getOrganizationMemberships(initialPage: initialPage, pageSize: pageSize)
  }

  /// Retrieves a list of organization suggestions for the user.
  /// - Parameters:
  ///   - initialPage: A number that can be used to skip the first n-1 pages. For example, if initialPage is set to 10, it is will skip the first 9 pages and will fetch the 10th page.
  ///   - pageSize: A number that indicates the maximum number of results that should be returned for a specific page.
  ///   - status: The status an invitation can have.
  /// - Returns: A ``ClerkPaginatedResponse`` of ``OrganizationSuggestion`` objects.
  @discardableResult @MainActor
  func getOrganizationSuggestions(
    initialPage: Int = 0,
    pageSize: Int = 20,
    status: String? = nil
  ) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> {
    try await userService.getOrganizationSuggestions(initialPage: initialPage, pageSize: pageSize, status: status)
  }

  /// Retrieves all active sessions for this user.
  ///
  /// This method uses a cache so a network request will only be triggered only once. Returns an array of SessionWithActivities objects.
  @discardableResult @MainActor
  func getSessions() async throws -> [Session] {
    try await userService.getSessions(user: self)
  }

  /// Updates the user's password. Passwords must be at least 8 characters long.
  @discardableResult @MainActor
  func updatePassword(_ params: UpdatePasswordParams) async throws -> User {
    try await userService.updatePassword(params: params)
  }

  /// Adds the user's profile image or replaces it if one already exists. This method will upload an image and associate it with the user.
  /// - Parameters:
  ///     - imageData: The image, in data format, to set as the user's profile image.
  @discardableResult @MainActor
  func setProfileImage(imageData: Data) async throws -> ImageResource {
    try await userService.setProfileImage(imageData: imageData)
  }

  /// Deletes the user's profile image.
  @discardableResult @MainActor
  func deleteProfileImage() async throws -> DeletedObject {
    try await userService.deleteProfileImage()
  }

  /// Deletes the current user.
  @discardableResult @MainActor
  func delete() async throws -> DeletedObject {
    try await userService.delete()
  }
}
