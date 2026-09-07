//
//  User.swift
//

// swiftlint:disable file_length

import Foundation
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

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
public struct User: Codable, Equatable, Sendable, Identifiable {
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

extension User {
  @MainActor
  private var userService: any UserServiceProtocol {
    Clerk.shared.dependencies.userService
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Connects an Apple account to the user using Sign in with Apple.
  ///
  /// This method handles the entire Sign in with Apple flow for connecting an external account, including:
  /// - Requesting Apple ID credentials
  /// - Extracting the ID token
  /// - Creating the external account
  ///
  /// - Parameters:
  ///   - requestedScopes: The scopes to request from Apple (defaults to `[.email, .fullName]`).
  /// - Returns: The created `ExternalAccount` object.
  /// - Throws: An error if the connection fails.
  @discardableResult @MainActor
  public func connectAppleAccount(requestedScopes: [ASAuthorization.Scope] = [.email, .fullName]) async throws -> ExternalAccount {
    let credential = try await SignInWithAppleHelper.getAppleIdCredential(requestedScopes: requestedScopes)

    guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
      throw ClerkClientError(message: "Unable to retrieve the Apple identity token.", localizationBundle: .module)
    }

    return try await createExternalAccount(provider: .apple, idToken: idToken)
  }
  #endif

  @discardableResult @MainActor
  public func getPaymentMethods(params: GetPaymentMethodsParams? = nil) async throws -> ClerkPaginatedResponse<BillingPaymentMethod> {
    try await Clerk.getUserPaymentMethods(initialPage: params?.initialPage, pageSize: params?.pageSize)
  }

  /// Adds the user's profile image or replaces it if one already exists. This method will upload an image and associate it with the user.
  /// - Parameters:
  ///     - imageData: The image, in data format, to set as the user's profile image.
  @discardableResult @MainActor
  public func setProfileImage(imageData: Data) async throws -> ImageResource {
    try await userService.setProfileImage(imageData: imageData)
  }

  /// Deletes the user's profile image.
  @discardableResult @MainActor
  public func deleteProfileImage() async throws -> DeletedObject {
    try await userService.deleteProfileImage()
  }
}
