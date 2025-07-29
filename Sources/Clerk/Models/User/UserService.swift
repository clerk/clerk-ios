//
//  UserService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import AuthenticationServices
import FactoryKit
import Foundation

extension Container {
  
  var userService: Factory<UserService> {
    self { @MainActor in UserService() }
  }
  
}

@MainActor
struct UserService {
  
  var update: (_ params: User.UpdateParams) async throws -> User = { params in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me")
      .method(.patch)
      .body(formEncode: params)
      .addClerkSessionId()
      .data(type: ClientResponse<User>.self)
      .async()
      .response
  }
  
  var createBackupCodes: () async throws -> BackupCodeResource = {
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/backup_codes")
      .method(.post)
      .addClerkSessionId()
      .data(type: ClientResponse<BackupCodeResource>.self)
      .async()
      .response
  }
  
  var createEmailAddress: (_ emailAddress: String) async throws -> EmailAddress = { emailAddress in
    try await EmailAddress.create(emailAddress)
  }
  
  var createPhoneNumber: (_ phoneNumber: String) async throws -> PhoneNumber = { phoneNumber in
    try await PhoneNumber.create(phoneNumber)
  }
  
  var createExternalAccount: (_ provider: OAuthProvider, _ redirectUrl: String?, _ additionalScopes: [String]?) async throws -> ExternalAccount = { provider, redirectUrl, additionalScopes in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/external_accounts")
      .method(.post)
      .addClerkSessionId()
      .body(
        formEncode: [
          "strategy": provider.strategy,
          "redirect_url": redirectUrl ?? Clerk.shared.settings.redirectConfig.redirectUrl,
          "additional_scopes": additionalScopes?.joined(separator: ","),
        ].filter({ $0.value != nil })
      )
      .data(type: ClientResponse<ExternalAccount>.self)
      .async()
      .response
  }
  
  var createExternalAccountToken: (_ provider: IDTokenProvider, _ idToken: String) async throws -> ExternalAccount = { provider, idToken in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/external_accounts")
      .method(.post)
      .addClerkSessionId()
      .body(formEncode: [
        "strategy": provider.strategy,
        "token": idToken,
      ])
      .data(type: ClientResponse<ExternalAccount>.self)
      .async()
      .response
  }
  
#if canImport(AuthenticationServices) && !os(watchOS)
  var createPasskey: () async throws -> Passkey = {
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
  
  var createTotp: () async throws -> TOTPResource = {
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/totp")
      .method(.post)
      .addClerkSessionId()
      .data(type: ClientResponse<TOTPResource>.self)
      .async()
      .response
  }
  
  var verifyTotp: (_ code: String) async throws -> TOTPResource = { code in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/totp/attempt_verification")
      .method(.post)
      .addClerkSessionId()
      .body(formEncode: ["code": code])
      .data(type: ClientResponse<TOTPResource>.self)
      .async()
      .response
  }
  
  var disableTotp: () async throws -> DeletedObject = {
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/totp")
      .method(.delete)
      .addClerkSessionId()
      .data(type: ClientResponse<DeletedObject>.self)
      .async()
      .response
  }
  
  var getOrganizationInvitations: (_ initialPage: Int, _ pageSize: Int) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> = { initialPage, pageSize in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/organization_invitations")
      .addClerkSessionId()
      .add(queryItems: [
        .init(name: "offset", value: String(initialPage)),
        .init(name: "limit", value: String(pageSize)),
      ])
      .data(type: ClientResponse<ClerkPaginatedResponse<UserOrganizationInvitation>>.self)
      .async()
      .response
  }
  
  var getOrganizationMemberships: (_ initialPage: Int, _ pageSize: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership> = { initialPage, pageSize in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/organization_memberships")
      .addClerkSessionId()
      .add(queryItems: [
        .init(name: "offset", value: String(initialPage)),
        .init(name: "limit", value: String(pageSize)),
        .init(name: "paginated", value: "true"),
      ])
      .data(type: ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>.self)
      .async()
      .response
  }
  
  var getOrganizationSuggestions: (_ initialPage: Int, _ pageSize: Int, _ status: String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> = { initialPage, pageSize, status in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/organization_suggestions")
      .addClerkSessionId()
      .add(
        queryItems: [
          .init(name: "offset", value: String(initialPage)),
          .init(name: "limit", value: String(pageSize)),
          .init(name: "status", value: status),
        ].filter({ $0.value != nil })
      )
      .data(type: ClientResponse<ClerkPaginatedResponse<OrganizationSuggestion>>.self)
      .async()
      .response
  }
  
  var getSessions: (_ user: User) async throws -> [Session] = { user in
    let sessions = try await Container.shared.apiClient().request()
      .add(path: "/v1/me/sessions/active")
      .addClerkSessionId()
      .data(type: [Session].self)
      .async()
    
    Clerk.shared.sessionsByUserId[user.id] = sessions
    return sessions
  }
  
  var updatePassword: (_ params: User.UpdatePasswordParams) async throws -> User = { params in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/change_password")
      .method(.post)
      .body(formEncode: params)
      .addClerkSessionId()
      .data(type: ClientResponse<User>.self)
      .async()
      .response
  }
  
  var setProfileImage: (_ imageData: Data) async throws -> ImageResource = { imageData in
    let boundary = UUID().uuidString
    var data = Data()
    data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    data.append(imageData)
    data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    
    return try await Container.shared.apiClient().request()
      .add(path: "/v1/me/profile_image")
      .method(.post)
      .body(data: data)
      .addClerkSessionId()
      .with {
        $0.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
      }
      .data(type: ClientResponse<ImageResource>.self)
      .async()
      .response
  }
  
  var deleteProfileImage: () async throws -> DeletedObject = {
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/profile_image")
      .method(.delete)
      .addClerkSessionId()
      .data(type: ClientResponse<DeletedObject>.self)
      .async()
      .response
  }
  
  var delete: () async throws -> DeletedObject = {
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me")
      .method(.delete)
      .addClerkSessionId()
      .data(type: ClientResponse<DeletedObject>.self)
      .async()
      .response
  }
  
}
