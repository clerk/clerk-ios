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
public struct User: Codable, Equatable {
    
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
    public let samlAccounts: [String]
    
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
    
    init(
        id: String = "",
        username: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        gender: String? = nil,
        birthday: String? = nil,
        imageUrl: String = "",
        hasImage: Bool = false,
        primaryEmailAddressId: String? = nil,
        primaryPhoneNumberId: String? = nil,
        primaryWeb3WalletId: String? = nil,
        passwordEnabled: Bool = false,
        twoFactorEnabled: Bool = false,
        totpEnabled: Bool = false,
        backupCodeEnabled: Bool = false,
        emailAddresses: [EmailAddress] = [],
        phoneNumbers: [PhoneNumber] = [],
        web3Wallets: [String] = [],
        externalAccounts: [ExternalAccount] = [],
        samlAccounts: [String] = [],
        publicMetadata: JSON? = nil,
        unsafeMetadata: JSON? = nil,
        externalId: String? = nil,
        lastSignInAt: Date = .now,
        banned: Bool = false,
        locked: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deleteSelfEnabled: Bool = false,
        createOrganizationEnabled: Bool = false
    ) {
        self.id = id
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.imageUrl = imageUrl
        self.hasImage = hasImage
        self.primaryEmailAddressId = primaryEmailAddressId
        self.primaryPhoneNumberId = primaryPhoneNumberId
        self.primaryWeb3WalletId = primaryWeb3WalletId
        self.passwordEnabled = passwordEnabled
        self.twoFactorEnabled = twoFactorEnabled
        self.totpEnabled = totpEnabled
        self.backupCodeEnabled = backupCodeEnabled
        self.emailAddresses = emailAddresses
        self.phoneNumbers = phoneNumbers
        self.web3Wallets = web3Wallets
        self.externalAccounts = externalAccounts
        self.samlAccounts = samlAccounts
        self.publicMetadata = publicMetadata
        self.unsafeMetadata = unsafeMetadata
        self.lastSignInAt = lastSignInAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deleteSelfEnabled = deleteSelfEnabled
        self.createOrganizationEnabled = createOrganizationEnabled
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
        externalAccounts.filter { $0.verification.status == .verified }
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
        let allExternalProviders = Clerk.shared.environment.userSettings.enabledThirdPartyProviders.sorted()
        let verifiedExternalProviders = verifiedExternalAccounts.compactMap(\.externalProvider)
        return allExternalProviders.filter { !verifiedExternalProviders.contains($0) }
    }
    
    var availableSecondFactors: [Clerk.Environment.UserSettings.Attribute: Clerk.Environment.UserSettings.AttributesConfig] {
        Clerk.shared.environment.userSettings.availableSecondFactors(user: self)
    }
    
    var phoneNumbersAvailableForSecondFactor: [PhoneNumber] {
        phoneNumbers.filter { !$0.reservedForSecondFactor }
    }
    
    var mfaPhones: [PhoneNumber] {
        phoneNumbers.filter { $0.verification.status == .verified && $0.reservedForSecondFactor }
    }
}

extension User {
    
    public struct RemoveUserPasswordParams: Encodable {
        public init(currentPassword: String) {
            self.currentPassword = currentPassword
        }
        
        /// The user's current password.
        let currentPassword: String
    }
    
}

extension User {
    
    /// Updates the user's attributes. Use this method to save information you collected about the user.
    @discardableResult
    @MainActor
    public func update(_ params: User.UpdateParams) async throws -> User {
        let request = ClerkAPI.v1.me.update(params)
        let response = try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client.get()
        return response
    }
    
    public struct UpdateParams: Encodable {
        /// The user's username.
        var username: String?
        
        /// The user's first name.
        var firstName: String?
        
        /// The user's last name.
        var lastName: String?
        
        /// The unique identifier for the EmailAddress that the user has set as primary.
        var primaryEmailAddressId: String?
        
        /// The unique identifier for the PhoneNumber that the user has set as primary.
        var primaryPhoneNumberId: String?
        
        /// The unique identifier for the Web3Wallet that the user signed up with.
        var primaryWeb3WalletId: String?
        
        /**
        Metadata that can be read and set from the Frontend API. One common use case for this attribute is to implement custom fields that will be attached to the User object.
        Please note that there is also an unsafeMetadata attribute in the SignUp object. The value of that field will be automatically copied to the user's unsafe metadata once the sign up is complete.
         */
        var unsafeMetadata: JSON?
    }
    
    @discardableResult
    @MainActor
    public func createEmailAddress(_ emailAddress: String) async throws -> EmailAddress {
        let params = EmailAddress.CreateParams(emailAddress: emailAddress)
        let request = ClerkAPI.v1.me.emailAddresses.post(params)
        let newEmail = try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client.get()
        return newEmail
    }
    
    @discardableResult
    @MainActor
    public func createPhoneNumber(_ phoneNumber: String) async throws -> PhoneNumber {
        let params = PhoneNumber.CreateParams(phoneNumber: phoneNumber)
        let request = ClerkAPI.v1.me.phoneNumbers.post(params)
        let newPhoneNumber = try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client.get()
        return newPhoneNumber
    }
    
    @discardableResult
    @MainActor
    public func createExternalAccount(_ provider: ExternalProvider) async throws -> ExternalAccount {
        let params = ExternalAccount.CreateParams(ExternalProvider: provider, redirectUrl: "clerk://")
        let request = ClerkAPI.v1.me.externalAccounts.create(params)
        let newExternalAccount = try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client.get()
        return newExternalAccount
    }
    
    /// Retrieves all active sessions for this user.
    @MainActor
    public func getSessions() async throws {
        let request = ClerkAPI.v1.me.sessions.active.get
        let sessions = try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value
        Clerk.shared.sessionsByUserId[id] = sessions
    }
    
    /// Updates the user's password.
    @MainActor
    public func updatePassword(_ params: UpdateUserPasswordParams) async throws {
        let request = ClerkAPI.v1.me.changePassword.post(params)
        try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }
        try await Clerk.shared.client.get()
    }
    
    public struct UpdateUserPasswordParams: Encodable {
        /// The user's new password.
        let newPassword: String
        /// The user's current password.
        let currentPassword: String
        /// If set to true, all sessions will be signed out.
        let signOutOfOtherSessions: Bool
    }
    
    /// Adds the user's profile image or replaces it if one already exists. This method will upload an image and associate it with the user.
    @discardableResult
    @MainActor
    public func setProfileImage(_ imageData: Data) async throws -> ClerkImageResource {
        let request = ClerkAPI.v1.me.profileImage.post
        let boundary = UUID().uuidString
        var data = Data()
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        data.append(imageData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        let imageResource = try await Clerk.apiClient.upload(for: request, from: data) {
            $0.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client.get()
        return imageResource
    }
    
    @MainActor
    public func deleteProfileImage() async throws {
        let request = ClerkAPI.v1.me.profileImage.delete
        try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }
        try await Clerk.shared.client.get()
    }
    
}
