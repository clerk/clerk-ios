#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
import ClerkSnapshots
import Foundation

extension User {
  /// Combined first and last name when either is present.
  public var fullName: String? {
    let name = [firstName, lastName]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    return name.isEmpty ? nil : name
  }

  /// Profile image URL when `imageUrl` is a non-empty string.
  public var imageURL: URL? {
    imageUrl.isEmpty ? nil : URL(string: imageUrl)
  }

  /// Username when the account has one.
  public var usernameHandle: String? {
    guard let username, !username.isEmpty else { return nil }
    return username
  }

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

  /// Information about the user's primary email address.
  public var primaryEmailAddress: EmailAddress? {
    emailAddresses.first(where: { $0.id == primaryEmailAddressId })
  }

  /// Information about the user's primary phone number.
  public var primaryPhoneNumber: PhoneNumber? {
    phoneNumbers.first(where: { $0.id == primaryPhoneNumberId })
  }

  /// A getter for the user's list of unverified external accounts.
  public var unverifiedExternalAccounts: [ExternalAccount] {
    externalAccounts.filter { externalAccount in
      externalAccount.verification?.status == .unverified
    }
  }

  /// A getter for the user's list of verified external accounts.
  public var verifiedExternalAccounts: [ExternalAccount] {
    externalAccounts.filter { externalAccount in
      externalAccount.verification?.status == .verified
    }
  }

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
