//
//  Account.swift
//  Clerk
//

import Foundation
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

/// The main entry point for current-user account operations in the Clerk SDK.
///
/// Access this via `clerk.account` to manage the signed-in user and related resources.
@MainActor
struct Account {
  private let clerk: Clerk
  private let userService: UserServiceProtocol
  private let emailAddressService: EmailAddressServiceProtocol
  private let phoneNumberService: PhoneNumberServiceProtocol
  private let externalAccountService: ExternalAccountServiceProtocol
  private let passkeyService: PasskeyServiceProtocol

  init(
    clerk: Clerk,
    userService: UserServiceProtocol,
    emailAddressService: EmailAddressServiceProtocol,
    phoneNumberService: PhoneNumberServiceProtocol,
    externalAccountService: ExternalAccountServiceProtocol,
    passkeyService: PasskeyServiceProtocol
  ) {
    self.clerk = clerk
    self.userService = userService
    self.emailAddressService = emailAddressService
    self.phoneNumberService = phoneNumberService
    self.externalAccountService = externalAccountService
    self.passkeyService = passkeyService
  }

  @discardableResult
  func reload() async throws -> User {
    try await userService.reload(sessionId: clerk.session?.id)
  }

  @discardableResult
  func update(_ params: User.UpdateParams) async throws -> User {
    try await userService.update(params: params, sessionId: clerk.session?.id)
  }

  @discardableResult
  func createBackupCodes() async throws -> BackupCodeResource {
    try await userService.createBackupCodes(sessionId: clerk.session?.id)
  }

  @discardableResult
  func createEmailAddress(_ emailAddress: String) async throws -> EmailAddress {
    try await emailAddressService.create(email: emailAddress, sessionId: clerk.session?.id)
  }

  @discardableResult
  func createPhoneNumber(_ phoneNumber: String) async throws -> PhoneNumber {
    try await phoneNumberService.create(phoneNumber: phoneNumber, sessionId: clerk.session?.id)
  }

  @discardableResult
  func createExternalAccount(
    provider: OAuthProvider,
    redirectUrl: String? = nil,
    additionalScopes: [String] = [],
    oidcPrompts: [OIDCPrompt] = []
  ) async throws -> ExternalAccount {
    try await userService.createExternalAccount(
      provider: provider,
      redirectUrl: redirectUrl ?? clerk.options.redirectConfig.redirectUrl,
      additionalScopes: additionalScopes,
      oidcPrompts: oidcPrompts,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func createExternalAccount(
    provider: IDTokenProvider,
    idToken: String
  ) async throws -> ExternalAccount {
    try await userService.createExternalAccountToken(provider: provider, idToken: idToken, sessionId: clerk.session?.id)
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @discardableResult
  func connectAppleAccount(
    requestedScopes: [ASAuthorization.Scope] = [.email, .fullName]
  ) async throws -> ExternalAccount {
    let credential = try await SignInWithAppleHelper.getAppleIdCredential(requestedScopes: requestedScopes)

    guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
      throw ClerkClientError(message: "Unable to retrieve the Apple identity token.")
    }

    return try await createExternalAccount(provider: .apple, idToken: idToken)
  }
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS)
  @discardableResult
  func createPasskey() async throws -> Passkey {
    let passkey = try await passkeyService.create(sessionId: clerk.session?.id)

    guard let challenge = passkey.challenge else {
      throw ClerkClientError(message: "Unable to get the challenge for the passkey.")
    }

    guard let name = passkey.username else {
      throw ClerkClientError(message: "Unable to get the username for the passkey.")
    }

    guard let userId = passkey.userId else {
      throw ClerkClientError(message: "Unable to get the user ID for the passkey.")
    }

    let manager = PasskeyHelper()
    let authorization = try await manager.createPasskey(
      challenge: challenge,
      name: name,
      userId: userId
    )

    guard
      let credentialRegistration = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration,
      let rawAttestationObject = credentialRegistration.rawAttestationObject
    else {
      throw ClerkClientError(message: "Invalid credential type.")
    }

    let publicKeyCredential: [String: Any] = [
      "id": credentialRegistration.credentialID.base64EncodedString().base64URLFromBase64String(),
      "rawId": credentialRegistration.credentialID.base64EncodedString().base64URLFromBase64String(),
      "type": "public-key",
      "response": [
        "attestationObject": rawAttestationObject.base64EncodedString().base64URLFromBase64String(),
        "clientDataJSON": credentialRegistration.rawClientDataJSON.base64EncodedString().base64URLFromBase64String(),
      ],
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: publicKeyCredential)
    guard let credential = String(data: jsonData, encoding: .utf8) else {
      throw ClerkClientError(message: "Unable to encode the passkey credential.")
    }

    return try await passkeyService.attemptVerification(
      passkeyId: passkey.id,
      credential: credential,
      sessionId: clerk.session?.id
    )
  }
  #endif

  @discardableResult
  func createTOTP() async throws -> TOTPResource {
    try await userService.createTotp(sessionId: clerk.session?.id)
  }

  @discardableResult
  func verifyTOTP(_ code: String) async throws -> TOTPResource {
    try await userService.verifyTotp(code: code, sessionId: clerk.session?.id)
  }

  @discardableResult
  func disableTOTP() async throws -> DeletedObject {
    try await userService.disableTotp(sessionId: clerk.session?.id)
  }

  @discardableResult
  func getOrganizationInvitations(
    page: Int = 1,
    pageSize: Int = 20,
    status: String? = nil
  ) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> {
    try await getOrganizationInvitations(
      offset: clerkPaginationOffset(forPage: page, pageSize: pageSize),
      pageSize: pageSize,
      status: status
    )
  }

  @discardableResult
  func getOrganizationInvitations(
    offset: Int = 0,
    pageSize: Int = 10,
    status: String? = nil
  ) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> {
    try await userService.getOrganizationInvitations(
      offset: offset,
      pageSize: pageSize,
      status: status,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func getOrganizationMemberships(
    page: Int = 1,
    pageSize: Int = 20
  ) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    try await getOrganizationMemberships(
      offset: clerkPaginationOffset(forPage: page, pageSize: pageSize),
      pageSize: pageSize
    )
  }

  @discardableResult
  func getOrganizationMemberships(
    offset: Int = 0,
    pageSize: Int = 10
  ) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    try await userService.getOrganizationMemberships(
      offset: offset,
      pageSize: pageSize,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func getOrganizationSuggestions(
    page: Int = 1,
    pageSize: Int = 20,
    status: [String] = []
  ) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> {
    try await getOrganizationSuggestions(
      offset: clerkPaginationOffset(forPage: page, pageSize: pageSize),
      pageSize: pageSize,
      status: status
    )
  }

  @discardableResult
  func getOrganizationSuggestions(
    offset: Int = 0,
    pageSize: Int = 10,
    status: [String] = []
  ) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> {
    try await userService.getOrganizationSuggestions(
      offset: offset,
      pageSize: pageSize,
      status: status,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func getOrganizationCreationDefaults() async throws -> OrganizationCreationDefaults {
    try await userService.getOrganizationCreationDefaults(sessionId: clerk.session?.id)
  }

  @discardableResult
  func getSessions(for user: User) async throws -> [Session] {
    guard user.id == clerk.user?.id else {
      throw ClerkClientError(message: "Cannot get sessions for a user that is not the active user.")
    }

    let sessions = try await userService.getSessions(sessionId: clerk.session?.id)
    clerk.sessionsByUserId[user.id] = sessions
    return sessions
  }

  @discardableResult
  func updatePassword(_ params: User.UpdatePasswordParams) async throws -> User {
    try await userService.updatePassword(params: params, sessionId: clerk.session?.id)
  }

  @discardableResult
  func setProfileImage(imageData: Data) async throws -> ImageResource {
    try await userService.setProfileImage(imageData: imageData, sessionId: clerk.session?.id)
  }

  @discardableResult
  func deleteProfileImage() async throws -> DeletedObject {
    try await userService.deleteProfileImage(sessionId: clerk.session?.id)
  }

  @discardableResult
  func delete() async throws -> DeletedObject {
    let deletedObject = try await userService.delete(sessionId: clerk.session?.id)
    clerk.auth.send(.accountDeleted)
    return deletedObject
  }

  @discardableResult
  func sendCode(to emailAddress: EmailAddress) async throws -> EmailAddress {
    try await emailAddressService.prepareVerification(
      emailAddressId: emailAddress.id,
      strategy: .emailCode,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func verifyCode(_ code: String, for emailAddress: EmailAddress) async throws -> EmailAddress {
    try await emailAddressService.attemptVerification(
      emailAddressId: emailAddress.id,
      strategy: .emailCode(code: code),
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func destroy(_ emailAddress: EmailAddress) async throws -> DeletedObject {
    try await emailAddressService.destroy(emailAddressId: emailAddress.id, sessionId: clerk.session?.id)
  }

  @discardableResult
  func delete(_ phoneNumber: PhoneNumber) async throws -> DeletedObject {
    try await phoneNumberService.delete(phoneNumberId: phoneNumber.id, sessionId: clerk.session?.id)
  }

  @discardableResult
  func sendCode(to phoneNumber: PhoneNumber) async throws -> PhoneNumber {
    try await phoneNumberService.prepareVerification(phoneNumberId: phoneNumber.id, sessionId: clerk.session?.id)
  }

  @discardableResult
  func verifyCode(_ code: String, for phoneNumber: PhoneNumber) async throws -> PhoneNumber {
    try await phoneNumberService.attemptVerification(
      phoneNumberId: phoneNumber.id,
      code: code,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func makeDefaultSecondFactor(for phoneNumber: PhoneNumber) async throws -> PhoneNumber {
    try await phoneNumberService.makeDefaultSecondFactor(phoneNumberId: phoneNumber.id, sessionId: clerk.session?.id)
  }

  @discardableResult
  func setReservedForSecondFactor(_ reserved: Bool = true, for phoneNumber: PhoneNumber) async throws -> PhoneNumber {
    try await phoneNumberService.setReservedForSecondFactor(
      phoneNumberId: phoneNumber.id,
      reserved: reserved,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func prepareReauthorization(
    for externalAccount: ExternalAccount,
    redirectUrl: String? = nil,
    additionalScopes: [String] = [],
    oidcPrompts: [OIDCPrompt] = []
  ) async throws -> ExternalAccount {
    try await externalAccountService.reauthorize(
      externalAccount.id,
      redirectUrl: redirectUrl ?? clerk.options.redirectConfig.redirectUrl,
      additionalScopes: additionalScopes,
      oidcPrompts: oidcPrompts,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func reauthorize(
    _ externalAccount: ExternalAccount,
    prefersEphemeralWebBrowserSession: Bool = false
  ) async throws -> ExternalAccount {
    let url = try clerkExternalAuthenticationURL(from: externalAccount.verification?.externalVerificationRedirectUrl)
    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )

    _ = try await authSession.start()

    try await clerk.refreshClient()
    guard let externalAccount = clerk.user?.externalAccounts.first(where: { $0.id == externalAccount.id }) else {
      throw ClerkClientError(message: "Something went wrong. Please try again.")
    }
    return externalAccount
  }

  @discardableResult
  func destroy(_ externalAccount: ExternalAccount) async throws -> DeletedObject {
    try await externalAccountService.destroy(externalAccount.id, sessionId: clerk.session?.id)
  }

  @discardableResult
  func update(_ passkey: Passkey, name: String) async throws -> Passkey {
    try await passkeyService.update(passkeyId: passkey.id, name: name, sessionId: clerk.session?.id)
  }

  @discardableResult
  func attemptVerification(_ credential: String, for passkey: Passkey) async throws -> Passkey {
    try await passkeyService.attemptVerification(
      passkeyId: passkey.id,
      credential: credential,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func delete(_ passkey: Passkey) async throws -> DeletedObject {
    try await passkeyService.delete(passkeyId: passkey.id, sessionId: clerk.session?.id)
  }
}
