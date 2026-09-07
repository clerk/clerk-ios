#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
import ClerkSnapshots
import Foundation

extension User {
  /// Reloads the user from the Clerk API.
  @discardableResult @MainActor
  public func reload() async throws -> User {
    try await Clerk.js(.user, UserJSCall.reload(nil))
    return try Clerk.requireUser()
  }

  /// Updates the user's attributes. Use this method to save information you collected about the user.
  ///
  /// The appropriate settings must be enabled in the Clerk Dashboard for the user to be able to update their attributes.
  ///
  /// For example, if you want to use the `update(.init(firstName:))` method, you must enable the Name setting.
  /// It can be found in the Email, phone, username > Personal information section in the Clerk Dashboard.
  ///
  /// - Important: Passing `unsafeMetadata` through ``User/UpdateParams`` is deprecated.
  ///   When `unsafeMetadata` is provided with other profile fields, the SDK sends two
  ///   requests: one to update profile fields and one to update metadata. These requests
  ///   are not atomic; if the metadata request fails, profile changes may already be saved.
  ///   Prefer ``updateMetadata(unsafeMetadata:)`` for metadata updates.
  @discardableResult @MainActor
  public func update(_ params: User.UpdateParams) async throws -> User {
    try await Clerk.js(
      .user,
      UserJSCall.update(
        UpdateUserParams(
          username: params.username,
          firstName: params.firstName,
          lastName: params.lastName,
          primaryEmailAddressId: params.primaryEmailAddressId,
          primaryPhoneNumberId: params.primaryPhoneNumberId,
          primaryWeb3WalletId: nil,
          unsafeMetadata: params.deprecatedUnsafeMetadata?.jsonValue
        )
      )
    )
    return try Clerk.requireUser()
  }

  /// Updates the user's unsafe metadata.
  ///
  /// Values are merged into the existing unsafe metadata. Set a key to `JSON.null` to remove it.
  @discardableResult @MainActor
  public func updateMetadata(_ params: User.UpdateMetadataParams) async throws -> User {
    try await Clerk.js(
      .user,
      UserJSCall.updateMetadata(UpdateUserMetadataParams(unsafeMetadata: params.unsafeMetadata.jsonValue))
    )
    return try Clerk.requireUser()
  }

  /// Updates the user's unsafe metadata.
  ///
  /// Values are merged into the existing unsafe metadata. Set a key to `JSON.null` to remove it.
  @discardableResult @MainActor
  public func updateMetadata(unsafeMetadata: JSON) async throws -> User {
    try await updateMetadata(.init(unsafeMetadata: unsafeMetadata))
  }

  /// Generates a fresh new set of backup codes for the user. Every time the method is called, it will replace the previously generated backup codes.
  ///
  /// - Returns: ``BackupCodeResource``
  @discardableResult @MainActor
  public func createBackupCodes() async throws -> BackupCodeResource {
    try await Clerk.js(.user, UserJSCall.createBackupCode, as: BackupCodeResource.self)
  }

  /// Adds an email address for the user. A new EmailAddress will be created and associated with the user.
  /// - Parameter email: The value of the email address.
  @discardableResult @MainActor
  public func createEmailAddress(_ emailAddress: String) async throws -> EmailAddress {
    try await Clerk.js(
      .user,
      UserJSCall.createEmailAddress(CreateEmailAddressParams(email: emailAddress)),
      as: EmailAddress.self
    )
  }

  /// Adds a phone number for the user. A new PhoneNumber will be created and associated with the user.
  /// - Parameter phoneNumber: The value of the phone number, in E.164 format.
  @discardableResult @MainActor
  public func createPhoneNumber(_ phoneNumber: String) async throws -> PhoneNumber {
    try await Clerk.js(
      .user,
      UserJSCall.createPhoneNumber(CreatePhoneNumberParams(phoneNumber: phoneNumber)),
      as: PhoneNumber.self
    )
  }

  /// Adds an external account for the user. A new ExternalAccount will be created and associated with the user.
  ///
  /// This method is useful if you want to allow an already signed-in user to connect their account with an external OAuth provider, such as Facebook, GitHub, etc., so that they can sign in with that provider in the future.
  /// - Parameters:
  ///    - provider: The OAuth provider. For example: `.facebook`, `.github`, etc.
  ///    - redirectUrl: The full URL or path that the OAuth provider should redirect to, on successful authorization on their part.
  ///    - additionalScopes: Additional scopes for your user to be prompted to approve.
  ///    - oidcPrompts: OIDC prompt values to include in the authorization request.
  @discardableResult @MainActor
  public func createExternalAccount(
    provider: OAuthProvider,
    redirectUrl: String? = nil,
    additionalScopes: [String]? = nil,
    oidcPrompts: [OIDCPrompt] = []
  ) async throws -> ExternalAccount {
    try await Clerk.js(
      .user,
      UserJSCall.createExternalAccount(
        CreateExternalAccountParams(
          strategy: provider.strategy,
          redirectUrl: redirectUrl ?? Clerk.shared.options.redirectConfig.redirectUrl,
          additionalScopes: additionalScopes,
          oidcPrompt: oidcPrompts.serializedPrompt
        )
      ),
      as: ExternalAccount.self
    )
  }

  /// Adds an external account for the user. A new ExternalAccount will be created and associated with the user.
  ///
  /// This method is useful if you want to allow an already signed-in user to connect their account with an external provider using an ID token provider, such as Apple, etc., so that they can sign in with that provider in the future.
  /// - Parameters:
  ///     - provider: The IDTokenProvider. For example: `.apple`.
  ///     - idToken: The ID token from the provider.
  @discardableResult @MainActor
  public func createExternalAccount(provider: IDTokenProvider, idToken: String) async throws -> ExternalAccount {
    try await Clerk.js(
      .user,
      UserJSCall.createExternalAccount(
        CreateExternalAccountParams(strategy: provider.strategy, token: idToken)
      ),
      as: ExternalAccount.self
    )
  }

  #if canImport(AuthenticationServices) && !os(watchOS)
  /// Creates a passkey for the signed-in user.
  ///
  /// - Returns: ``Passkey``
  @discardableResult @MainActor
  public func createPasskey() async throws -> Passkey {
    try await Clerk.js(.user, UserJSCall.createPasskey, as: Passkey.self)
  }
  #endif

  /// Generates a TOTP secret for a user that can be used to register the application on the user's authenticator app of choice.
  ///
  /// Note that if this method is called again (while still unverified), it replaces the previously generated secret.
  @discardableResult @MainActor
  public func createTOTP() async throws -> TOTPResource {
    try await Clerk.js(.user, UserJSCall.createTOTP, as: TOTPResource.self)
  }

  /// Verifies a TOTP secret after a user has created it.
  ///
  /// The user must provide a code from their authenticator app, that has been generated using the previously created secret.
  /// This way, correct set up and ownership of the authenticator app can be validated.
  /// - Parameter code: A 6 digit TOTP generated from the user's authenticator app.
  @discardableResult @MainActor
  public func verifyTOTP(code: String) async throws -> TOTPResource {
    try await Clerk.js(.user, UserJSCall.verifyTOTP(VerifyTOTPParams(code: code)), as: TOTPResource.self)
  }

  /// Disables TOTP by deleting the user's TOTP secret.
  @discardableResult @MainActor
  public func disableTOTP() async throws -> DeletedObject {
    try await Clerk.js(.user, UserJSCall.disableTOTP, as: DeletedObject.self)
  }

  /// Retrieves a list of organization invitations for the user.
  /// - Parameters:
  ///   - page: The 1-based page number to fetch. Defaults to `1`.
  ///   - pageSize: A number that indicates the maximum number of results that should be returned for a specific page. Defaults to `20`.
  ///   - status: An array of invitation statuses to filter by. Defaults to an empty array, which applies no status filter.
  /// - Returns: A ``ClerkPaginatedResponse`` of ``UserOrganizationInvitation`` objects.
  @discardableResult @MainActor
  public func getOrganizationInvitations(
    page: Int = 1,
    pageSize: Int = 20,
    status: [String] = []
  ) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> {
    try await Clerk.js(
      .user,
      UserJSCall.getOrganizationInvitations(
        GetUserOrganizationInvitationsParams(
          initialPage: page,
          pageSize: pageSize,
          status: status.first.map(invitationStatus(from:))
        )
      ),
      as: ClerkPaginatedResponse<UserOrganizationInvitation>.self
    )
  }

  @discardableResult @MainActor
  package func getOrganizationInvitations(
    offset: Int = 0,
    pageSize: Int = 10,
    status: [String] = []
  ) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> {
    try await getOrganizationInvitations(
      page: page(fromOffset: offset, pageSize: pageSize),
      pageSize: pageSize,
      status: status
    )
  }

  /// Retrieves a list of organization memberships for the user.
  /// - Parameters:
  ///   - page: The 1-based page number to fetch. Defaults to `1`.
  ///   - pageSize: A number that indicates the maximum number of results that should be returned for a specific page. Defaults to `20`.
  /// - Returns: A ``ClerkPaginatedResponse`` of ``OrganizationMembership`` objects.
  @discardableResult @MainActor
  public func getOrganizationMemberships(
    page: Int = 1,
    pageSize: Int = 20
  ) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    try await Clerk.js(
      .user,
      UserJSCall.getOrganizationMemberships(
        GetUserOrganizationMembershipParams(initialPage: page, pageSize: pageSize)
      ),
      as: ClerkPaginatedResponse<OrganizationMembership>.self
    )
  }

  @discardableResult @MainActor
  package func getOrganizationMemberships(
    offset: Int = 0,
    pageSize: Int = 10
  ) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    try await getOrganizationMemberships(
      page: page(fromOffset: offset, pageSize: pageSize),
      pageSize: pageSize
    )
  }

  /// Leaves the organization with the provided id.
  /// - Parameter organizationId: The id of the organization to leave.
  /// - Returns: A ``DeletedObject`` response.
  @discardableResult @MainActor
  public func leaveOrganization(organizationId: String) async throws -> DeletedObject {
    try await Clerk.js(
      .user,
      UserJSCall.leaveOrganization(organizationId: organizationId),
      as: DeletedObject.self
    )
  }

  /// Retrieves a list of organization suggestions for the user.
  /// - Parameters:
  ///   - page: The 1-based page number to fetch. Defaults to `1`.
  ///   - pageSize: A number that indicates the maximum number of results that should be returned for a specific page. Defaults to `20`.
  ///   - status: An array of suggestion statuses to filter by. Defaults to an empty array, which applies no status filter.
  /// - Returns: A ``ClerkPaginatedResponse`` of ``OrganizationSuggestion`` objects.
  @discardableResult @MainActor
  public func getOrganizationSuggestions(
    page: Int = 1,
    pageSize: Int = 20,
    status: [String] = []
  ) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> {
    try await Clerk.js(
      .user,
      UserJSCall.getOrganizationSuggestions(
        GetUserOrganizationSuggestionsParams(
          initialPage: page,
          pageSize: pageSize,
          status: status.isEmpty ? nil : .array(status.map(JSONValue.string))
        )
      ),
      as: ClerkPaginatedResponse<OrganizationSuggestion>.self
    )
  }

  @discardableResult @MainActor
  package func getOrganizationSuggestions(
    offset: Int = 0,
    pageSize: Int = 10,
    status: [String] = []
  ) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> {
    try await getOrganizationSuggestions(
      page: page(fromOffset: offset, pageSize: pageSize),
      pageSize: pageSize,
      status: status
    )
  }

  /// Retrieves the organization creation defaults for this user.
  ///
  /// Returns pre-filled form values (name, slug, logo) based on the instance's default naming rules.
  /// - Returns: An ``OrganizationCreationDefaults`` object.
  @discardableResult @MainActor
  public func getOrganizationCreationDefaults() async throws -> OrganizationCreationDefaults {
    try await Clerk.js(.user, UserJSCall.getOrganizationCreationDefaults, as: OrganizationCreationDefaults.self)
  }

  /// Retrieves all active sessions for this user.
  ///
  /// This method uses a cache so a network request will only be triggered only once. Returns an array of SessionWithActivities objects.
  @discardableResult @MainActor
  public func getSessions() async throws -> [Session] {
    let sessions = try await Clerk.js(.user, UserJSCall.getSessions, as: [Session].self)
    Clerk.shared.sessionsByUserId[id] = sessions
    return sessions
  }

  /// Updates the user's password. Passwords must be at least 8 characters long.
  @discardableResult @MainActor
  public func updatePassword(_ params: UpdatePasswordParams) async throws -> User {
    try await Clerk.js(
      .user,
      UserJSCall.updatePassword(
        UpdateUserPasswordParams(
          newPassword: params.newPassword,
          currentPassword: params.currentPassword,
          signOutOfOtherSessions: params.signOutOfOtherSessions
        )
      )
    )
    return try Clerk.requireUser()
  }

  /// Deletes the current user.
  @discardableResult @MainActor
  public func delete() async throws -> DeletedObject {
    let deleted = try await Clerk.js(.user, UserJSCall.delete, as: DeletedObject.self)
    Clerk.shared.auth.send(.accountDeleted)
    return deleted
  }

  private func page(fromOffset offset: Int, pageSize: Int) -> Int {
    guard pageSize > 0 else { return 1 }
    return offset / pageSize + 1
  }

  private func invitationStatus(from raw: String) -> GetUserOrganizationInvitationsParamsStatus {
    switch raw {
    case "expired":
      .expired
    case "revoked":
      .revoked
    case "pending":
      .pending
    case "accepted":
      .accepted
    default:
      .unknown(raw)
    }
  }
}
