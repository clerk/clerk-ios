//
//  PhoneNumber.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import Foundation
import PhoneNumberKit
import Factory

/**
 The `PhoneNumber` object describes a phone number. Phone numbers can be used as a proof of identification for users, or simply as a means of contacting users.

 Phone numbers must be verified to ensure that they can be assigned to their rightful owners. The `PhoneNumber` object holds all the necessary state around the verification process.

 The verification process always starts with the `PhoneNumber.prepareVerification()` method, which will send a one-time verification code via an SMS message. The second and final step involves an attempt to complete the verification by calling the `PhoneNumber.attemptVerification()` method, passing the one-time code as a parameter.

 Finally, phone numbers are used as part of multi-factor authentication. Users receive an SMS message with a one-time code that they need to provide as an extra verification step.
 */
public struct PhoneNumber: Codable, Equatable, Hashable, Identifiable {
    
    /// A unique identifier for this phone number.
    public let id: String
    
    /// The value of this phone number, in E.164 format.
    public let phoneNumber: String
    
    /// Set to true if this phone number is reserved for multi-factor authentication (2FA). Set to false otherwise.
    public let reservedForSecondFactor: Bool
    
    /// Set to true if this phone number is the default second factor. Set to false otherwise. A user must have exactly one default second factor, if multi-factor authentication (2FA) is enabled.
    public let defaultSecondFactor: Bool
    
    /// An object holding information on the verification of this phone number.
    public let verification: Verification?
    
    /// An object containing information about any other identification that might be linked to this phone number.
    let linkedTo: AnyJSON?
    
    ///
    public let backupCodes: [String]?
    
    init(
        id: String,
        phoneNumber: String,
        reservedForSecondFactor: Bool = false,
        defaultSecondFactor: Bool = false,
        verification: Verification? = nil,
        linkedTo: AnyJSON? = nil,
        backupCodes: [String]? = nil
    ) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.reservedForSecondFactor = reservedForSecondFactor
        self.defaultSecondFactor = defaultSecondFactor
        self.verification = verification
        self.linkedTo = linkedTo
        self.backupCodes = backupCodes
    }
}

extension PhoneNumber {
    
    func isPrimary(for user: User) -> Bool {
        user.primaryPhoneNumberId == id
    }
    
    var regionId: String? {
        let phoneNumberKit = Container.shared.phoneNumberKit()
        guard let phoneNumber = try? phoneNumberKit.parse(phoneNumber) else { return nil }
        return phoneNumber.regionID
    }
    
    var flag: String? {
        let phoneNumberKit = Container.shared.phoneNumberKit()
        guard let phoneNumber = try? phoneNumberKit.parse(phoneNumber) else { return phoneNumber }

        if
            let region = phoneNumber.regionID,
            let country = CountryCodePickerViewController.Country(for: region, with: phoneNumberKit)
        {
            return country.flag
        }
        
        return nil
    }
    
    func formatted(_ format: PhoneNumberFormat) -> String {
        let phoneNumberKit = Container.shared.phoneNumberKit()
        guard let phoneNumber = try? phoneNumberKit.parse(phoneNumber) else { return phoneNumber }
        return phoneNumberKit.format(phoneNumber, toType: format)
    }
    
}

extension PhoneNumber {
    
    public struct CreateParams: Encodable {
        /// The value of the phone number, in E.164 format.
        public let phoneNumber: String
    }
    
    public struct PrepareParams: Encodable {
        public init(strategy: Strategy) {
            self.strategy = strategy.stringValue
        }
        
        public let strategy: String
    }
    
    public struct AttemptParams: Encodable {
        public init(code: String) {
            self.code = code
        }
        
        public let code: String
    }
    
}

extension PhoneNumber {
    
    @MainActor
    public func prepareVerification(strategy: PrepareStrategy) async throws {
        let params = prepareParams(for: strategy)
        let request = ClerkAPI
            .v1
            .me
            .phoneNumbers
            .id(id)
            .prepareVerification
            .post(params)
        
        try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }
        try await Clerk.shared.client.get()
    }
    
    public enum PrepareStrategy {
        case phoneCode
    }
    
    private func prepareParams(for strategy: PrepareStrategy) -> PrepareParams {
        switch strategy {
        case .phoneCode:
            return .init(strategy: .phoneCode)
        }
    }
    
    @MainActor
    public func attemptVerification(strategy: AttemptStrategy) async throws {
        let params = attemptParams(for: strategy)
        let request = ClerkAPI
            .v1
            .me
            .phoneNumbers
            .id(id)
            .attemptVerification
            .post(params)
        
        try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }
        try await Clerk.shared.client.get()
    }
    
    public enum AttemptStrategy {
        case phoneCode(code: String)
    }
    
    private func attemptParams(for strategy: AttemptStrategy) -> AttemptParams {
        switch strategy {
        case .phoneCode(let code):
            return .init(code: code)
        }
    }
    
    /// Marks this phone number as reserved for multi-factor authentication (2FA) or not.
    /// - Parameter reserved: Pass true to mark this phone number as reserved for 2FA, or false to disable 2FA for this phone number.
    @MainActor
    @discardableResult
    public func setReservedForSecondFactor(reserved: Bool = true) async throws -> PhoneNumber {
        let body = ["reserved_for_second_factor": reserved]
        let request = ClerkAPI.v1.me.phoneNumbers.id(id).patch(body: body)
        let phoneNumber = try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        try await Clerk.shared.client.get()
        return phoneNumber
    }
    
    @MainActor
    public func setAsPrimary() async throws {
        let request = ClerkAPI.v1.me.update(.init(primaryPhoneNumberId: id))
        try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }
        try await Clerk.shared.client.get()
    }
    
    @MainActor
    public func delete() async throws {
        let request = ClerkAPI.v1.me.phoneNumbers.id(id).delete
        try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }
        try await Clerk.shared.client.get()
    }
    
}
