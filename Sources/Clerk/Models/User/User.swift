//
//  User.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

import Foundation
import AuthenticationServices

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
public struct User: Codable, Equatable, Sendable, Hashable {
    
    /// The unique identifier for the user.
    public let id: String
    
    /// The user's first name.
    public let firstName: String?
    
    /// The user's last name.
    public let lastName: String?
    
    /// The user's username.
    public let username: String?
    
    /// A getter boolean to check if the user has uploaded an image or one was copied from OAuth. Returns false if Clerk is displaying an avatar for the user.
    public let hasImage: Bool
    
    /// Holds the default avatar or user's uploaded profile image
    public let imageUrl: String
    
    /// An array of all the Passkey objects associated with the user.
    public let passkeys: [Passkey]
    
    /// Information about the user's primary email address.
    public var primaryEmailAddress: EmailAddress? {
        emailAddresses.first(where: { $0.id == primaryEmailAddressId })
    }
    
    /// The unique identifier for the EmailAddress that the user has set as primary.
    public let primaryEmailAddressId: String?
    
    /// An array of all the EmailAddress objects associated with the user. Includes the primary.
    public let emailAddresses: [EmailAddress]
    
    /// A getter boolean to check if the user has verified an email address.
    public var hasVerifiedEmailAddress: Bool {
        emailAddresses.contains { emailAddress in
            emailAddress.verification?.status == .verified
        }
    }
    
    /// Information about the user's primary phone number.
    public var primaryPhoneNumber: PhoneNumber? {
        phoneNumbers.first(where: { $0.id == primaryPhoneNumberId })
    }
    
    /// The unique identifier for the PhoneNumber that the user has set as primary.
    public let primaryPhoneNumberId: String?
    
    /// An array of all the PhoneNumber objects associated with the user. Includes the primary.
    public let phoneNumbers: [PhoneNumber]
    
    /// A getter boolean to check if the user has verified a phone number.
    public var hasVerifiedPhoneNumber: Bool {
        phoneNumbers.contains { phoneNumber in
            phoneNumber.verification?.status == .verified
        }
    }
    
    /// An array of all the ExternalAccount objects associated with the user via OAuth. Note: This includes both verified & unverified external accounts.
    public let externalAccounts: [ExternalAccount]
    
    /// A getter for the user's list of verified external accounts.
    public var verifiedExternalAccounts: [ExternalAccount] {
        externalAccounts.filter { externalAccount in
            externalAccount.verification?.status == .verified
        }
    }
    
    /// A getter for the user's list of unverified external accounts.
    public var unverifiedExternalAccounts: [ExternalAccount] {
        externalAccounts.filter { externalAccount in
            externalAccount.verification?.status == .unverified
        }
    }
    
    /// A list of enterprise accounts associated with the user.
    public let enterpriseAccounts: [EnterpriseAccount]?
    
    /// A boolean indicating whether the user has a password on their account.
    public let passwordEnabled: Bool
    
    /// A boolean indicating whether the user has enabled TOTP by generating a TOTP secret and verifying it via an authenticator app.
    public let totpEnabled: Bool
    
    /// A boolean indicating whether the user has enabled two-factor authentication.
    public let twoFactorEnabled: Bool
    
    /// A boolean indicating whether the user has enabled Backup codes.
    public let backupCodeEnabled: Bool

    /// A boolean indicating whether the organization creation is enabled for the user or not.
    public let createOrganizationEnabled: Bool
    
    /// An integer indicating the number of organizations that can be created by the user. If the value is 0, then the user can create unlimited organizations. Default is null.
    public let createOrganizationsLimit: Int?
    
    /// A boolean indicating whether the user is able to delete their own account or not.
    public let deleteSelfEnabled: Bool
    
    /// Metadata that can be read from the Frontend API and Backend API and can be set only from the Backend API .
    public let publicMetadata: JSON?
    
    /**
     Metadata that can be read and set from the Frontend API. One common use case for this attribute is to implement custom fields that will be attached to the User object.
     Please note that there is also an unsafeMetadata attribute in the SignUp object. The value of that field will be automatically copied to the user's unsafe metadata once the sign up is complete.
     */
    public let unsafeMetadata: JSON?
    
    /// The date on which the user accepted the legal requirements if required.
    public let legalAcceptedAt: Date?
    
    /// Date when the user last signed in. May be empty if the user has never signed in.
    public let lastSignInAt: Date?
    
    /// Date when the user was first created.
    public let createdAt: Date
    
    /// Date of the last time the user was updated.
    public let updatedAt: Date
}

extension User {
    
    /// Updates the user's attributes. Use this method to save information you collected about the user.
    @discardableResult @MainActor
    public func update(_ params: User.UpdateParams) async throws -> User {
        let request = ClerkFAPI.v1.me.update(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: params
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Adds an email address for the user. A new EmailAddress will be created and associated with the user.
    /// - Parameter email: The value of the email address
    @discardableResult @MainActor
    public func createEmailAddress(_ email: String) async throws -> EmailAddress {
        let request = ClerkFAPI.v1.me.emailAddresses.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["email_address": email]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Creates a new phone number for the current user.
    /// - Parameter phoneNumber: The value of the phone number, in E.164 format.
    @discardableResult @MainActor
    public func createPhoneNumber(_ phoneNumber: String) async throws -> PhoneNumber {
        let request = ClerkFAPI.v1.me.phoneNumbers.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["phone_number": phoneNumber]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
     /// Adds an external account for the user. A new `ExternalAccount` will be created and associated with the user.
     ///
     /// The initial state of the returned ExternalAccount will be unverified. To initiate the connection with the external provider one should redirect to the externalAccount.verification.externalVerificationRedirectURL contained in the result of createExternalAccount.
     /// Upon return, one can inspect within the user.externalAccounts the entry that corresponds to the requested strategy:
     ///
     /// - If the connection was successful then externalAccount.verification.status should be verified.
     /// - If the connection was not successful, then the externalAccount.verification.status will not be verified and the externalAccount.verification.error will contain the error encountered so that you can present corresponding feedback to the user.
    @discardableResult @MainActor
    public func createExternalAccount(_ provider: OAuthProvider, additionalScopes: [String]? = nil) async throws -> ExternalAccount {
        let request = ClerkFAPI.v1.me.externalAccounts.create(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "strategy": provider.strategy,
                "redirect_url": Clerk.shared.redirectConfig.redirectUrl,
                "additional_scopes": additionalScopes?.joined(separator: ",")
            ]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    @discardableResult @MainActor
    public func createExternalAccount(_ provider: IDTokenProvider, idToken: String) async throws -> ExternalAccount {
        let request = ClerkFAPI.v1.me.externalAccounts.create(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "strategy": provider.strategy,
                "token": idToken
            ]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    #if canImport(AuthenticationServices) && !os(watchOS)
    @MainActor
    @discardableResult
    public func createPasskey() async throws -> Passkey {
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
        
        let manager = PasskeyManager()
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
        
        let registeredPasskey = try await passkey.attemptVerification(
            credential: publicKeyCredentialJSON.debugDescription
        )
        
        return registeredPasskey
    }
    #endif
    
    /// Generates a TOTP secret for a user that can be used to register the application on the user's authenticator app of choice. Note that if this method is called again (while still unverified), it replaces the previously generated secret.
    @discardableResult @MainActor
    public func createTOTP() async throws -> TOTPResource {
        let request = ClerkFAPI.v1.me.totp.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Verifies a TOTP secret after a user has created it. The user must provide a code from their authenticator app, that has been generated using the previously created secret. This way, correct set up and ownership of the authenticator app can be validated.
    /// - Parameter code: A 6 digit TOTP generated from the user's authenticator app.
    @discardableResult @MainActor
    public func verifyTOTP(code: String) async throws -> TOTPResource {
        let request = ClerkFAPI.v1.me.totp.attemptVerification.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["code": code]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Disables TOTP by deleting the user's TOTP secret.
    @discardableResult @MainActor
    public func disableTOTP() async throws -> DeletedObject {
        let request = ClerkFAPI.v1.me.totp.delete(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Retrieves all active sessions for this user.
    @discardableResult @MainActor
    public func getSessions() async throws -> [Session] {
        let request = ClerkFAPI.v1.me.sessions.active.get(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let sessions = try await Clerk.shared.apiClient.send(request).value
        Clerk.shared.sessionsByUserId[id] = sessions
        return sessions
    }
    
    /// Updates the user's password.
    @discardableResult @MainActor
    public func updatePassword(_ params: UpdatePasswordParams) async throws -> User {
        let request = ClerkFAPI.v1.me.changePassword.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: params
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Adds the user's profile image or replaces it if one already exists. This method will upload an image and associate it with the user.
    @discardableResult @MainActor
    public func setProfileImage(_ imageData: Data) async throws -> ImageResource {
        
        let boundary = UUID().uuidString
        var data = Data()
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        data.append(imageData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        let request = ClerkFAPI.v1.me.profileImage.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
        )
        
        let response = try await Clerk.shared.apiClient.upload(for: request, from: data)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Deletes the user's profile image.
    @discardableResult @MainActor
    public func deleteProfileImage() async throws -> DeletedObject {
        let request = ClerkFAPI.v1.me.profileImage.delete(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client

        return response.value.response
    }
    
    /// Deletes the current user.
    @discardableResult @MainActor
    public func delete() async throws -> DeletedObject {
        let request = ClerkFAPI.v1.me.delete(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        
        return response.value.response
    }
    
}
