//
//  User.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

import Foundation

/**
 The `User` object holds all of the information for a single user of your application and provides a set of methods to manage their account. Each user has a unique authentication identifier which might be their email address, phone number, or a username.

 A user can be contacted at their primary email address or primary phone number. They can have more than one registered email address, but only one of them will be their primary email address. This goes for phone numbers as well; a user can have more than one, but only one phone number will be their primary. At the same time, a user can also have one or more external accounts by connecting to OAuth providers such as Google, Apple, Facebook, and many more.

 Finally, a `User` object holds profile data like the user's name, profile picture, and a set of metadata that can be used internally to store arbitrary information. The metadata are split into `publicMetadata` and `privateMetadata`. Both types are set from the Backend API, but public metadata can also be accessed from the Frontend API.
 */
public struct User: Codable, Equatable, Sendable {
    
    /// A unique identifier for the user.
    public let id: String
    
    /// The user's first name.
    public let firstName: String?
    
    /// The user's last name.
    public let lastName: String?
    
    /// The user's username.
    public let username: String?
    
    /// Holds the users profile image or avatar.
    public let imageUrl: String
    
    /// A getter boolean to check if the user has uploaded an image or one was copied from OAuth. Returns false if Clerk is displaying an avatar for the user.
    public let hasImage: Bool
    
    /// The unique identifier for the EmailAddress that the user has set as primary.
    public  let primaryEmailAddressId: String?
    
    /// An array of all the EmailAddress objects associated with the user. Includes the primary.
    public let emailAddresses: [EmailAddress]
    
    /// The unique identifier for the PhoneNumber that the user has set as primary.
    public  let primaryPhoneNumberId: String?
    
    /// An array of all the PhoneNumber objects associated with the user. Includes the primary.
    public let phoneNumbers: [PhoneNumber]
    
    /// The unique identifier for the Web3Wallet that the user signed up with.
    public  let primaryWeb3WalletId: String?
    
    /// An array of all the Web3Wallet objects associated with the user. Includes the primary.
    public let web3Wallets: [String]
    
    /// A boolean indicating whether the user has a password on their account.
    public  let passwordEnabled: Bool
    
    /// A boolean indicating whether the user has enabled two-factor authentication.
    public  let twoFactorEnabled: Bool
    
    /// A boolean indicating whether the user has enabled TOTP by generating a TOTP secret and verifying it via an authenticator app.
    public let totpEnabled: Bool
    
    /// A boolean indicating whether the user has enabled Backup codes.
    public let backupCodeEnabled: Bool
    
    /// A boolean indicating whether the user is able to delete their own account or not.
    public let deleteSelfEnabled: Bool
    
    /// An array of all the ExternalAccount objects associated with the user via OAuth. Note: This includes both verified & unverified external accounts.
    public let externalAccounts: [ExternalAccount]
    
    /// An experimental list of saml accounts associated with the user.
    public let samlAccounts: [SAMLAccount]?
    
    /// Metadata that can be read from the Frontend API and Backend API and can be set only from the Backend API .
    public let publicMetadata: JSON?
    
    /**
     Metadata that can be read and set from the Frontend API. One common use case for this attribute is to implement custom fields that will be attached to the User object.
     Please note that there is also an unsafeMetadata attribute in the SignUp object. The value of that field will be automatically copied to the user's unsafe metadata once the sign up is complete.
     */
    public let unsafeMetadata: JSON?
    
    /// Date when the user last signed in. May be empty if the user has never signed in.
    public let lastSignInAt: Date
    
    /// Date when the user was first created.
    public let createdAt: Date
    
    /// Date of the last time the user was updated.
    public let updatedAt: Date
    
    /// A boolean indicating whether the organization creation is enabled for the user or not.
    public let createOrganizationEnabled: Bool
    
    /// A boolean that returns true if the user is signed in.
    public var isSignedIn: Bool {
        let activeUserIds = Clerk.shared.client?.activeSessions.compactMap(\.user?.id) ?? []
        return activeUserIds.contains(id)
    }
    
    /// The user's full name.
    public var fullName: String? {
        let joinedString = [firstName, lastName]
            .compactMap { $0 }
            .filter({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return joinedString.isEmpty ? nil : joinedString
    }
    
    /// Information about the user's primary email address.
    public var primaryEmailAddress: EmailAddress? {
        guard let primaryEmailAddressId else { return nil }
        return emailAddresses.first(where: { $0.id == primaryEmailAddressId })
    }
    
    /// Information about the user's primary phone number.
    public var primaryPhoneNumber: PhoneNumber? {
        guard let primaryPhoneNumberId else { return nil }
        return phoneNumbers.first(where: { $0.id == primaryPhoneNumberId })
    }
    
    /// A getter for the user's list of verified external accounts.
    public var verifiedExternalAccounts: [ExternalAccount] {
        externalAccounts.filter { $0.verification?.status == .verified }
    }
}

extension User {
    
    var initials: String? {
        let joinedString = [firstName, lastName]
            .compactMap { $0?.first }
            .map { String($0) }
            .joined()
        
        return joinedString.isEmpty ? nil : joinedString
    }
    
    var identifier: String? {
        username ?? primaryEmailAddress?.emailAddress ?? primaryPhoneNumber?.phoneNumber
    }
    
    var unconnectedProviders: [ExternalProvider] {
        guard let environment = Clerk.shared.environment else { return []}
        let allExternalProviders = environment.userSettings.enabledThirdPartyProviders.sorted()
        let verifiedExternalProviders = verifiedExternalAccounts.compactMap(\.externalProvider)
        return allExternalProviders.filter { !verifiedExternalProviders.contains($0) }
    }
    
    var availableSecondFactors: [Clerk.Environment.UserSettings.Attribute: Clerk.Environment.UserSettings.AttributesConfig] {
        guard let environment = Clerk.shared.environment else { return [:] }
        return environment.userSettings.availableSecondFactors(user: self)
    }
    
    var phoneNumbersAvailableForSecondFactor: [PhoneNumber] {
        phoneNumbers.filter { !$0.reservedForSecondFactor }
    }
    
    var mfaPhones: [PhoneNumber] {
        phoneNumbers.filter { $0.verification?.status == .verified && $0.reservedForSecondFactor }
    }
}

extension User {
    
    /// Updates the user's attributes. Use this method to save information you collected about the user.
    @discardableResult @MainActor
    public func update(_ params: User.UpdateParams) async throws -> User {
        let request = ClerkAPI.v1.me.update(params)
        let response = try await Clerk.shared.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client?.get()
        return response
    }
    
    public struct UpdateParams: Encodable {
        /// The user's username.
        public var username: String?
        
        /// The user's first name.
        public var firstName: String?
        
        /// The user's last name.
        public var lastName: String?
        
        /// The unique identifier for the EmailAddress that the user has set as primary.
        public var primaryEmailAddressId: String?
        
        /// The unique identifier for the PhoneNumber that the user has set as primary.
        public var primaryPhoneNumberId: String?
        
        /// The unique identifier for the Web3Wallet that the user signed up with.
        public var primaryWeb3WalletId: String?
        
        /**
        Metadata that can be read and set from the Frontend API. One common use case for this attribute is to implement custom fields that will be attached to the User object.
        Please note that there is also an unsafeMetadata attribute in the SignUp object. The value of that field will be automatically copied to the user's unsafe metadata once the sign up is complete.
         */
        public var unsafeMetadata: JSON?
    }
    
    /// Adds an email address for the user. A new EmailAddress will be created and associated with the user.
    /// - Parameter email: The value of the email address
    @discardableResult @MainActor
    public func createEmailAddress(_ email: String) async throws -> EmailAddress {
        let params = CreateEmailAddressParams(emailAddress: email)
        let request = ClerkAPI.v1.me.emailAddresses.post(params)
        let newEmail = try await Clerk.shared.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client?.get()
        return newEmail
    }
    
    public struct CreateEmailAddressParams: Encodable {
        public let emailAddress: String
    }
    
    /// Creates a new phone number for the current user.
    /// - Parameter phoneNumber: The value of the phone number, in E.164 format.
    @discardableResult @MainActor
    public func createPhoneNumber(_ phoneNumber: String) async throws -> PhoneNumber {
        let params = CreatePhoneNumberParams(phoneNumber: phoneNumber)
        let request = ClerkAPI.v1.me.phoneNumbers.post(params)
        let newPhoneNumber = try await Clerk.shared.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client?.get()
        return newPhoneNumber
    }
    
    public struct CreatePhoneNumberParams: Encodable {
        /// The value of the phone number, in E.164 format.
        public let phoneNumber: String
    }
    
     /// Adds an external account for the user. A new `ExternalAccount` will be created and associated with the user.
     ///
     /// The initial state of the returned ExternalAccount will be unverified. To initiate the connection with the external provider one should redirect to the externalAccount.verification.externalVerificationRedirectURL contained in the result of createExternalAccount.
     /// Upon return, one can inspect within the user.externalAccounts the entry that corresponds to the requested strategy:
     ///
     /// - If the connection was successful then externalAccount.verification.status should be verified.
     /// - If the connection was not successful, then the externalAccount.verification.status will not be verified and the externalAccount.verification.error will contain the error encountered so that you can present corresponding feedback to the user.
    @discardableResult @MainActor
    public func createExternalAccount(_ provider: ExternalProvider) async throws -> ExternalAccount {
        let params = CreateExternalAccountParams(ExternalProvider: provider)
        let request = ClerkAPI.v1.me.externalAccounts.create(params)
        let newExternalAccount = try await Clerk.shared.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client?.get()
        return newExternalAccount
    }
    
    public struct CreateExternalAccountParams: Encodable {
        init(
            ExternalProvider: ExternalProvider,
            additionalScopes: [String]? = nil
        ) {
            self.strategy = ExternalProvider.data.strategy
            self.additionalScopes = additionalScopes
        }
        
        /// The strategy corresponding to the oauth provider, e.g. `oauth_facebook`, `oauth_github`, etc.
        let strategy: String
        
        /// Any additional scopes you would like your user to be prompted to approve.
        let additionalScopes: [String]?
        
        /// The URL to redirect back to one the oauth flow has completed successfully or unsuccessfully.
        private let redirectUrl: String = Clerk.shared.redirectConfig.redirectUrl
    }
    
    /// Generates a TOTP secret for a user that can be used to register the application on the user's authenticator app of choice. Note that if this method is called again (while still unverified), it replaces the previously generated secret.
    @discardableResult @MainActor
    public func createTOTP() async throws -> TOTPResource {
        let request = ClerkAPI.v1.me.totp.post
        let totp = try await Clerk.shared.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client?.get()
        return totp
    }
    
    /// Verifies a TOTP secret after a user has created it. The user must provide a code from their authenticator app, that has been generated using the previously created secret. This way, correct set up and ownership of the authenticator app can be validated.
    /// - Parameter code: A 6 digit TOTP generated from the user's authenticator app.
    @discardableResult @MainActor
    public func verifyTOTP(code: String) async throws -> TOTPResource {
        let request = ClerkAPI.v1.me.totp.attemptVerification.post(code: code)
        let totp = try await Clerk.shared.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client?.get()
        return totp
    }
    
    /// Disables TOTP by deleting the user's TOTP secret.
    @MainActor
    public func disableTOTP() async throws {
        let request = ClerkAPI.v1.me.totp.delete
        try await Clerk.shared.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }
        try await Clerk.shared.client?.get()
    }
    
    /// Retrieves all active sessions for this user.
    @discardableResult @MainActor
    public func getSessions() async throws -> [Session] {
        let request = ClerkAPI.v1.me.sessions.active.get
        let sessions = try await Clerk.shared.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value
        Clerk.shared.sessionsByUserId[id] = sessions
        return sessions
    }
    
    /// Updates the user's password.
    @discardableResult @MainActor
    public func updatePassword(_ params: User.UpdatePasswordParams) async throws -> User {
        let request = ClerkAPI.v1.me.changePassword.post(params)
        let user = try await Clerk.shared.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client?.get()
        return user
    }
    
    public struct UpdatePasswordParams: Encodable {
        /// The user's new password.
        public let newPassword: String
        /// The user's current password.
        public let currentPassword: String
        /// If set to true, all sessions will be signed out.
        public let signOutOfOtherSessions: Bool
    }
    
    /// Adds the user's profile image or replaces it if one already exists. This method will upload an image and associate it with the user.
    @discardableResult @MainActor
    public func setProfileImage(_ imageData: Data) async throws -> ClerkImageResource {
        let request = ClerkAPI.v1.me.profileImage.post
        let boundary = UUID().uuidString
        var data = Data()
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        data.append(imageData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        let imageResource = try await Clerk.shared.apiClient.upload(for: request, from: data) {
            $0.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client?.get()
        return imageResource
    }
    
    /// Deletes the user's profile image.
    @discardableResult @MainActor
    public func deleteProfileImage() async throws -> ClerkImageResource {
        let request = ClerkAPI.v1.me.profileImage.delete
        let imageResource = try await Clerk.shared.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client?.get()
        return imageResource
        
    }
    
    /// Deletes the current user.
    @MainActor
    public func delete() async throws {
        let request = ClerkAPI.v1.me.delete()
        try await Clerk.shared.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }
        try await Clerk.shared.client?.get()
    }
    
}
