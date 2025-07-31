//
//  UserService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import AuthenticationServices
import FactoryKit
import Foundation
import Get

extension Container {

    var userService: Factory<UserService> {
        self { UserService() }
    }

}

struct UserService {

    var update: @MainActor (_ params: User.UpdateParams) async throws -> User = { params in
        let request = Request<ClientResponse<User>>.init(
            path: "/v1/me",
            method: .patch,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: params
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var createBackupCodes: @MainActor () async throws -> BackupCodeResource = {
        let request = Request<ClientResponse<BackupCodeResource>>.init(
            path: "/v1/me/backup_codes",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var createEmailAddress: @MainActor (_ emailAddress: String) async throws -> EmailAddress = { emailAddress in
        try await EmailAddress.create(emailAddress)
    }

    var createPhoneNumber: @MainActor (_ phoneNumber: String) async throws -> PhoneNumber = { phoneNumber in
        try await PhoneNumber.create(phoneNumber)
    }

    var createExternalAccount: @MainActor (_ provider: OAuthProvider, _ redirectUrl: String?, _ additionalScopes: [String]?) async throws -> ExternalAccount = { provider, redirectUrl, additionalScopes in
        var bodyParams: [String: String] = [
            "strategy": provider.strategy,
            "redirect_url": redirectUrl ?? Clerk.shared.settings.redirectConfig.redirectUrl
        ]
        
        if let additionalScopes = additionalScopes {
            bodyParams["additional_scopes"] = additionalScopes.joined(separator: ",")
        }
        
        let request = Request<ClientResponse<ExternalAccount>>.init(
            path: "/v1/me/external_accounts",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: bodyParams
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var createExternalAccountToken: @MainActor (_ provider: IDTokenProvider, _ idToken: String) async throws -> ExternalAccount = { provider, idToken in
        let request = Request<ClientResponse<ExternalAccount>>.init(
            path: "/v1/me/external_accounts",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "strategy": provider.strategy,
                "token": idToken
            ]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    #if canImport(AuthenticationServices) && !os(watchOS)
    var createPasskey: @MainActor () async throws -> Passkey = {
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
                "clientDataJSON": credentialRegistration.rawClientDataJSON.base64EncodedString().base64URLFromBase64String()
            ]
        ]

        let publicKeyCredentialJSON = try JSON(publicKeyCredential)

        return try await passkey.attemptVerification(credential: publicKeyCredentialJSON.debugDescription)
    }
    #endif

    var createTotp: @MainActor () async throws -> TOTPResource = {
        let request = Request<ClientResponse<TOTPResource>>.init(
            path: "/v1/me/totp",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var verifyTotp: @MainActor (_ code: String) async throws -> TOTPResource = { code in
        let request = Request<ClientResponse<TOTPResource>>.init(
            path: "/v1/me/totp/attempt_verification",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["code": code]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var disableTotp: @MainActor () async throws -> DeletedObject = {
        let request = Request<ClientResponse<DeletedObject>>.init(
            path: "/v1/me/totp",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var getOrganizationInvitations: @MainActor (_ initialPage: Int, _ pageSize: Int) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation> = { initialPage, pageSize in
        let request = Request<ClientResponse<ClerkPaginatedResponse<UserOrganizationInvitation>>>.init(
            path: "/v1/me/organization_invitations",
            method: .get,
            query: [
                ("_clerk_session_id", value: Clerk.shared.session?.id),
                ("offset", value: String(initialPage)),
                ("limit", value: String(pageSize))
            ]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var getOrganizationMemberships: @MainActor (_ initialPage: Int, _ pageSize: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership> = { initialPage, pageSize in
        let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>>.init(
            path: "/v1/me/organization_memberships",
            method: .get,
            query: [
                ("_clerk_session_id", value: Clerk.shared.session?.id),
                ("offset", value: String(initialPage)),
                ("limit", value: String(pageSize)),
                ("paginated", value: "true")
            ]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var getOrganizationSuggestions: @MainActor (_ initialPage: Int, _ pageSize: Int, _ status: String?) async throws -> ClerkPaginatedResponse<OrganizationSuggestion> = { initialPage, pageSize, status in
        var queryParams: [(String, String?)] = [
            ("_clerk_session_id", value: Clerk.shared.session?.id),
            ("offset", value: String(initialPage)),
            ("limit", value: String(pageSize))
        ]
        
        if let status = status {
            queryParams.append(("status", value: status))
        }
        
        let request = Request<ClientResponse<ClerkPaginatedResponse<OrganizationSuggestion>>>.init(
            path: "/v1/me/organization_suggestions",
            method: .get,
            query: queryParams
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var getSessions: @MainActor (_ user: User) async throws -> [Session] = { user in
        let request = Request<[Session]>.init(
            path: "/v1/me/sessions/active",
            method: .get,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let sessions = try await Container.shared.apiClient().send(request).value
        Clerk.shared.sessionsByUserId[user.id] = sessions
        return sessions
    }

    var updatePassword: @MainActor (_ params: User.UpdatePasswordParams) async throws -> User = { params in
        let request = Request<ClientResponse<User>>.init(
            path: "/v1/me/change_password",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: params
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var setProfileImage: @MainActor (_ imageData: Data) async throws -> ImageResource = { imageData in
        let boundary = UUID().uuidString
        var data = Data()
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        data.append(imageData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let request = Request<ClientResponse<ImageResource>>.init(
            path: "/v1/me/profile_image",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: data,
            headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var deleteProfileImage: @MainActor () async throws -> DeletedObject = {
        let request = Request<ClientResponse<DeletedObject>>.init(
            path: "/v1/me/profile_image",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var delete: @MainActor () async throws -> DeletedObject = {
        let request = Request<ClientResponse<DeletedObject>>.init(
            path: "/v1/me",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

}
