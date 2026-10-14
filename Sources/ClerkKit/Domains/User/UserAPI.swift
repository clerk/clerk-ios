//
//  UserAPI.swift
//  Clerk
//

import Foundation

package enum UserAPI {
  package static func reload() -> Request<ClientResponse<User>> {
    Request(
      path: "/v1/me",
      method: .get,
      scopedToActiveSession: true
    )
  }

  package static func update(params: User.UpdateParams) -> Request<ClientResponse<User>> {
    Request(
      path: "/v1/me",
      method: .patch,
      scopedToActiveSession: true,
      body: params
    )
  }

  package static func updateMetadata(params: User.UpdateMetadataParams) -> Request<ClientResponse<User>> {
    Request(
      path: "/v1/me/metadata",
      method: .patch,
      scopedToActiveSession: true,
      body: params
    )
  }

  package static func createBackupCodes() -> Request<ClientResponse<BackupCodeResource>> {
    Request(
      path: "/v1/me/backup_codes",
      method: .post,
      scopedToActiveSession: true
    )
  }

  package static func createExternalAccount(
    provider: OAuthProvider,
    redirectUrl: String,
    additionalScopes: [String],
    oidcPrompts: [OIDCPrompt]
  ) -> Request<ClientResponse<ExternalAccount>> {
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

    return Request(
      path: "/v1/me/external_accounts",
      method: .post,
      scopedToActiveSession: true,
      body: bodyParams
    )
  }

  package static func createExternalAccountToken(provider: IDTokenProvider, idToken: String) -> Request<ClientResponse<ExternalAccount>> {
    Request(
      path: "/v1/me/external_accounts",
      method: .post,
      scopedToActiveSession: true,
      body: [
        "strategy": provider.strategy,
        "token": idToken,
      ]
    )
  }

  package static func createTotp() -> Request<ClientResponse<TOTPResource>> {
    Request(
      path: "/v1/me/totp",
      method: .post,
      scopedToActiveSession: true
    )
  }

  package static func verifyTotp(code: String) -> Request<ClientResponse<TOTPResource>> {
    Request(
      path: "/v1/me/totp/attempt_verification",
      method: .post,
      scopedToActiveSession: true,
      body: ["code": code]
    )
  }

  package static func disableTotp() -> Request<ClientResponse<DeletedObject>> {
    Request(
      path: "/v1/me/totp",
      method: .delete,
      scopedToActiveSession: true
    )
  }

  package static func getOrganizationInvitations(
    offset: Int,
    pageSize: Int,
    status: [String]
  ) -> Request<ClientResponse<ClerkPaginatedResponse<UserOrganizationInvitation>>> {
    var queryParams: [(String, String?)] = [
      ("offset", value: String(offset)),
      ("limit", value: String(pageSize)),
    ]

    queryParams += status.map { ("status", $0 as String?) }

    return Request(
      path: "/v1/me/organization_invitations",
      method: .get,
      scopedToActiveSession: true,
      query: queryParams
    )
  }

  package static func getOrganizationMemberships(offset: Int, pageSize: Int) -> Request<ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>> {
    Request(
      path: "/v1/me/organization_memberships",
      method: .get,
      scopedToActiveSession: true,
      query: [
        ("offset", value: String(offset)),
        ("limit", value: String(pageSize)),
        ("paginated", value: "true"),
      ]
    )
  }

  package static func leaveOrganization(organizationId: String) -> Request<ClientResponse<DeletedObject>> {
    Request(
      path: "/v1/me/organization_memberships/\(organizationId)",
      method: .delete,
      scopedToActiveSession: true
    )
  }

  package static func getOrganizationSuggestions(
    offset: Int,
    pageSize: Int,
    status: [String]
  ) -> Request<ClientResponse<ClerkPaginatedResponse<OrganizationSuggestion>>> {
    var queryParams: [(String, String?)] = [
      ("offset", value: String(offset)),
      ("limit", value: String(pageSize)),
    ]

    queryParams += status.map { ("status", $0 as String?) }

    return Request(
      path: "/v1/me/organization_suggestions",
      method: .get,
      scopedToActiveSession: true,
      query: queryParams
    )
  }

  package static func getOrganizationCreationDefaults() -> Request<ClientResponse<OrganizationCreationDefaults>> {
    Request(
      path: "/v1/me/organization_creation_defaults",
      method: .get,
      scopedToActiveSession: true
    )
  }

  package static func getSessions() -> Request<[Session]> {
    Request(
      path: "/v1/me/sessions/active",
      method: .get,
      scopedToActiveSession: true
    )
  }

  package static func updatePassword(params: User.UpdatePasswordParams) -> Request<ClientResponse<User>> {
    Request(
      path: "/v1/me/change_password",
      method: .post,
      scopedToActiveSession: true,
      body: params
    )
  }

  package static func setProfileImage(boundary: String) -> Request<ClientResponse<ImageResource>> {
    Request(
      path: "/v1/me/profile_image",
      method: .post,
      headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
      scopedToActiveSession: true
    )
  }

  package static func deleteProfileImage() -> Request<ClientResponse<DeletedObject>> {
    Request(
      path: "/v1/me/profile_image",
      method: .delete,
      scopedToActiveSession: true
    )
  }

  package static func delete() -> Request<ClientResponse<DeletedObject>> {
    Request(
      path: "/v1/me",
      method: .delete,
      scopedToActiveSession: true
    )
  }
}
