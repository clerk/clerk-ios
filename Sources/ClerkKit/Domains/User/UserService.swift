//
//  UserService.swift
//  Clerk
//

import Foundation

protocol UserServiceProtocol: Sendable {
  @MainActor func reload(sessionId: String?) async throws -> User
  @MainActor func update(params: User.UpdateParams, sessionId: String?) async throws -> User
  @MainActor func createBackupCodes(sessionId: String?) async throws -> BackupCodeResource
  @MainActor func createExternalAccount(provider: OAuthProvider, redirectUrl: String, additionalScopes: [String], oidcPrompts: [OIDCPrompt], sessionId: String?) async throws -> ExternalAccount
  @MainActor func createExternalAccountToken(provider: IDTokenProvider, idToken: String, sessionId: String?) async throws -> ExternalAccount
  @MainActor func createTotp(sessionId: String?) async throws -> TOTPResource
  @MainActor func verifyTotp(code: String, sessionId: String?) async throws -> TOTPResource
  @MainActor func disableTotp(sessionId: String?) async throws -> DeletedObject
  @MainActor func getOrganizationInvitations(offset: Int, pageSize: Int, status: String?, sessionId: String?) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation>
  @MainActor func getOrganizationMemberships(offset: Int, pageSize: Int, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationMembership>
  @MainActor func getOrganizationSuggestions(offset: Int, pageSize: Int, status: [String], sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion>
  @MainActor func getOrganizationCreationDefaults(sessionId: String?) async throws -> OrganizationCreationDefaults
  @MainActor func getSessions(sessionId: String?) async throws -> [Session]
  @MainActor func updatePassword(params: User.UpdatePasswordParams, sessionId: String?) async throws -> User
  @MainActor func setProfileImage(imageData: Data, sessionId: String?) async throws -> ImageResource
  @MainActor func deleteProfileImage(sessionId: String?) async throws -> DeletedObject
  @MainActor func delete(sessionId: String?) async throws -> DeletedObject
}

// swiftlint:disable:next type_body_length
final class UserService: UserServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func reload(sessionId: String?) async throws -> User {
    let request = Request<ClientResponse<User>>(
      path: "/v1/me",
      method: .get,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func update(params: User.UpdateParams, sessionId: String?) async throws -> User {
    let request = Request<ClientResponse<User>>(
      path: "/v1/me",
      method: .patch,
      query: [("_clerk_session_id", value: sessionId)],
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func createBackupCodes(sessionId: String?) async throws -> BackupCodeResource {
    let request = Request<ClientResponse<BackupCodeResource>>(
      path: "/v1/me/backup_codes",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func createExternalAccount(
    provider: OAuthProvider,
    redirectUrl: String,
    additionalScopes: [String],
    oidcPrompts: [OIDCPrompt],
    sessionId: String?
  ) async throws -> ExternalAccount {
    var bodyParams: [String: JSON] = [
      "strategy": .string(provider.strategy),
      "redirect_url": .string(redirectUrl),
    ]

    if !additionalScopes.isEmpty {
      bodyParams["additional_scope"] = .array(additionalScopes.map { .string($0) })
    }

    if let serializedPrompt = oidcPrompts.serializedPrompt {
      bodyParams["oidc_prompt"] = .string(serializedPrompt)
    }

    let request = Request<ClientResponse<ExternalAccount>>(
      path: "/v1/me/external_accounts",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: bodyParams
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func createExternalAccountToken(provider: IDTokenProvider, idToken: String, sessionId: String?) async throws -> ExternalAccount {
    let request = Request<ClientResponse<ExternalAccount>>(
      path: "/v1/me/external_accounts",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: [
        "strategy": provider.strategy,
        "token": idToken,
      ]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func createTotp(sessionId: String?) async throws -> TOTPResource {
    let request = Request<ClientResponse<TOTPResource>>(
      path: "/v1/me/totp",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func verifyTotp(code: String, sessionId: String?) async throws -> TOTPResource {
    let request = Request<ClientResponse<TOTPResource>>(
      path: "/v1/me/totp/attempt_verification",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: ["code": code]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func disableTotp(sessionId: String?) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/totp",
      method: .delete,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getOrganizationInvitations(offset: Int, pageSize: Int, status: String?, sessionId: String?) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> {
    var queryParams: [(String, String?)] = [
      ("_clerk_session_id", value: sessionId),
      ("offset", value: String(offset)),
      ("limit", value: String(pageSize)),
    ]

    if let status {
      queryParams.append(("status", value: status))
    }

    let request = Request<ClientResponse<ClerkPaginatedResponse<UserOrganizationInvitation>>>(
      path: "/v1/me/organization_invitations",
      method: .get,
      query: queryParams
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getOrganizationMemberships(offset: Int, pageSize: Int, sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationMembership> {
    let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>>(
      path: "/v1/me/organization_memberships",
      method: .get,
      query: [
        ("_clerk_session_id", value: sessionId),
        ("offset", value: String(offset)),
        ("limit", value: String(pageSize)),
        ("paginated", value: "true"),
      ]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getOrganizationSuggestions(offset: Int, pageSize: Int, status: [String], sessionId: String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> {
    var queryParams: [(String, String?)] = [
      ("_clerk_session_id", value: sessionId),
      ("offset", value: String(offset)),
      ("limit", value: String(pageSize)),
    ]

    queryParams += status.map { ("status", $0 as String?) }

    let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationSuggestion>>>(
      path: "/v1/me/organization_suggestions",
      method: .get,
      query: queryParams
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getOrganizationCreationDefaults(sessionId: String?) async throws -> OrganizationCreationDefaults {
    let request = Request<ClientResponse<OrganizationCreationDefaults>>(
      path: "/v1/me/organization_creation_defaults",
      method: .get,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getSessions(sessionId: String?) async throws -> [Session] {
    let request = Request<[Session]>(
      path: "/v1/me/sessions/active",
      method: .get,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value
  }

  @MainActor
  func updatePassword(params: User.UpdatePasswordParams, sessionId: String?) async throws -> User {
    let request = Request<ClientResponse<User>>(
      path: "/v1/me/change_password",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func setProfileImage(imageData: Data, sessionId: String?) async throws -> ImageResource {
    let boundary = UUID().uuidString
    var data = Data()
    data.append(Data("\r\n--\(boundary)\r\n".utf8))
    data.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".utf8))
    data.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
    data.append(imageData)
    data.append(Data("\r\n--\(boundary)--\r\n".utf8))

    let request = Request<ClientResponse<ImageResource>>(
      path: "/v1/me/profile_image",
      method: .post,
      headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.upload(for: request, from: data).value.response
  }

  @MainActor
  func deleteProfileImage(sessionId: String?) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/profile_image",
      method: .delete,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func delete(sessionId: String?) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me",
      method: .delete,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }
}
