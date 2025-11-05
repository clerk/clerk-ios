//
//  UserService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import AuthenticationServices
import Foundation

protocol UserServiceProtocol: Sendable {
  @MainActor func reload() async throws -> User
  @MainActor func update(params: User.UpdateParams) async throws -> User
  @MainActor func createBackupCodes() async throws -> BackupCodeResource
  @MainActor func createEmailAddress(emailAddress: String) async throws -> EmailAddress
  @MainActor func createPhoneNumber(phoneNumber: String) async throws -> PhoneNumber
  @MainActor func createExternalAccount(provider: OAuthProvider, redirectUrl: String?, additionalScopes: [String]?) async throws -> ExternalAccount
  @MainActor func createExternalAccountToken(provider: IDTokenProvider, idToken: String) async throws -> ExternalAccount
  #if canImport(AuthenticationServices) && !os(watchOS)
  @MainActor func createPasskey() async throws -> Passkey
  #endif
  @MainActor func createTotp() async throws -> TOTPResource
  @MainActor func verifyTotp(code: String) async throws -> TOTPResource
  @MainActor func disableTotp() async throws -> DeletedObject
  @MainActor func getOrganizationInvitations(initialPage: Int, pageSize: Int) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation>
  @MainActor func getOrganizationMemberships(initialPage: Int, pageSize: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>
  @MainActor func getOrganizationSuggestions(initialPage: Int, pageSize: Int, status: String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion>
  @MainActor func getSessions(user: User) async throws -> [Session]
  @MainActor func updatePassword(params: User.UpdatePasswordParams) async throws -> User
  @MainActor func setProfileImage(imageData: Data) async throws -> ImageResource
  @MainActor func deleteProfileImage() async throws -> DeletedObject
  @MainActor func delete() async throws -> DeletedObject
}

final class UserService: UserServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func reload() async throws -> User {
    let request = Request<ClientResponse<User>>(
      path: "/v1/me",
      method: .get,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func update(params: User.UpdateParams) async throws -> User {
    let request = Request<ClientResponse<User>>(
      path: "/v1/me",
      method: .patch,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func createBackupCodes() async throws -> BackupCodeResource {
    let request = Request<ClientResponse<BackupCodeResource>>(
      path: "/v1/me/backup_codes",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func createEmailAddress(emailAddress: String) async throws -> EmailAddress {
    try await EmailAddress.create(emailAddress)
  }

  @MainActor
  func createPhoneNumber(phoneNumber: String) async throws -> PhoneNumber {
    try await PhoneNumber.create(phoneNumber)
  }

  @MainActor
  func createExternalAccount(provider: OAuthProvider, redirectUrl: String?, additionalScopes: [String]?) async throws -> ExternalAccount {
    var bodyParams: [String: String] = [
      "strategy": provider.strategy,
      "redirect_url": redirectUrl ?? Clerk.shared.options.redirectConfig.redirectUrl,
    ]

    if let additionalScopes {
      bodyParams["additional_scopes"] = additionalScopes.joined(separator: ",")
    }

    let request = Request<ClientResponse<ExternalAccount>>(
      path: "/v1/me/external_accounts",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: bodyParams
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func createExternalAccountToken(provider: IDTokenProvider, idToken: String) async throws -> ExternalAccount {
    let request = Request<ClientResponse<ExternalAccount>>(
      path: "/v1/me/external_accounts",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: [
        "strategy": provider.strategy,
        "token": idToken,
      ]
    )

    return try await apiClient.send(request).value.response
  }

  #if canImport(AuthenticationServices) && !os(watchOS)
  @MainActor
  func createPasskey() async throws -> Passkey {
    let passkey = try await Passkey.create()

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

    let publicKeyCredential: [String: any Encodable] = [
      "id": credentialRegistration.credentialID.base64EncodedString().base64URLFromBase64String(),
      "rawId": credentialRegistration.credentialID.base64EncodedString().base64URLFromBase64String(),
      "type": "public-key",
      "response": [
        "attestationObject": rawAttestationObject.base64EncodedString().base64URLFromBase64String(),
        "clientDataJSON": credentialRegistration.rawClientDataJSON.base64EncodedString().base64URLFromBase64String(),
      ],
    ]

    let publicKeyCredentialJSON = try JSON(publicKeyCredential)
    return try await passkey.attemptVerification(credential: publicKeyCredentialJSON.debugDescription)
  }
  #endif

  @MainActor
  func createTotp() async throws -> TOTPResource {
    let request = Request<ClientResponse<TOTPResource>>(
      path: "/v1/me/totp",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func verifyTotp(code: String) async throws -> TOTPResource {
    let request = Request<ClientResponse<TOTPResource>>(
      path: "/v1/me/totp/attempt_verification",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: ["code": code]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func disableTotp() async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/totp",
      method: .delete,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getOrganizationInvitations(initialPage: Int, pageSize: Int) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> {
    let request = Request<ClientResponse<ClerkPaginatedResponse<UserOrganizationInvitation>>>(
      path: "/v1/me/organization_invitations",
      method: .get,
      query: [
        ("_clerk_session_id", value: Clerk.shared.session?.id),
        ("offset", value: String(initialPage)),
        ("limit", value: String(pageSize)),
      ]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getOrganizationMemberships(initialPage: Int, pageSize: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>>(
      path: "/v1/me/organization_memberships",
      method: .get,
      query: [
        ("_clerk_session_id", value: Clerk.shared.session?.id),
        ("offset", value: String(initialPage)),
        ("limit", value: String(pageSize)),
        ("paginated", value: "true"),
      ]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getOrganizationSuggestions(initialPage: Int, pageSize: Int, status: String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> {
    var queryParams: [(String, String?)] = [
      ("_clerk_session_id", value: Clerk.shared.session?.id),
      ("offset", value: String(initialPage)),
      ("limit", value: String(pageSize)),
    ]

    if let status {
      queryParams.append(("status", value: status))
    }

    let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationSuggestion>>>(
      path: "/v1/me/organization_suggestions",
      method: .get,
      query: queryParams
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getSessions(user: User) async throws -> [Session] {
    let request = Request<[Session]>(
      path: "/v1/me/sessions/active",
      method: .get,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    let sessions = try await apiClient.send(request).value
    Clerk.shared.sessionsByUserId[user.id] = sessions
    return sessions
  }

  @MainActor
  func updatePassword(params: User.UpdatePasswordParams) async throws -> User {
    let request = Request<ClientResponse<User>>(
      path: "/v1/me/change_password",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func setProfileImage(imageData: Data) async throws -> ImageResource {
    let boundary = UUID().uuidString
    var data = Data()
    data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    data.append(imageData)
    data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

    let request = Request<ClientResponse<ImageResource>>(
      path: "/v1/me/profile_image",
      method: .post,
      headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.upload(for: request, from: data).value.response
  }

  @MainActor
  func deleteProfileImage() async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/profile_image",
      method: .delete,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func delete() async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me",
      method: .delete,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }
}
