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
 The PhoneNumber object describes a phone number. Phone numbers can be used as a proof of identification for users, or simply as a means of contacting users.

 Phone numbers must be verified to ensure that they can be assigned to their rightful owners. The PhoneNumber object holds all the necessary state around the verification process.

 The verification process always starts with the PhoneNumber.prepareVerification() method, which will send a one-time verification code via an SMS message. The second and final step involves an attempt to complete the verification by calling the PhoneNumber.attemptVerification() method, passing the one-time code as a parameter.

 Finally, phone numbers are used as part of multi-factor authentication. Users receive an SMS message with a one-time code that they need to provide as an extra verification step.
 */
public struct PhoneNumber: Decodable, Identifiable {
    /// A unique identifier for this phone number.
    public let id: String
    
    /// The value of this phone number, in E.164 format.
    public let phoneNumber: String
    
    /// Set to true if this phone number is reserved for multi-factor authentication (2FA). Set to false otherwise.
    let reservedForSecondFactor: Bool
    
    /// Set to true if this phone number is the default second factor. Set to false otherwise. A user must have exactly one default second factor, if multi-factor authentication (2FA) is enabled.
    let defaultSecondFactor: Bool
    
    /// An object holding information on the verification of this phone number.
    let verification: Verification
    
    /// An object containing information about any other identification that might be linked to this phone number.
    let linkedTo: JSON?
    
    ///
    let backupCodes: [String]?
}

extension Container {
    
    public var phoneNumberKit: Factory<PhoneNumberKit> {
        self { PhoneNumberKit() }
            .singleton
    }
    
}

extension PhoneNumber {
    
    public var isPrimary: Bool {
        Clerk.shared.client.lastActiveSession?.user.primaryPhoneNumberId == id
    }
    
    public var flag: String? {
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
    
    public func formatted(_ format: PhoneNumberFormat) -> String {
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
    
    public enum PrepareStrategy {
        case phoneCode
    }
    
    private func prepareParams(for strategy: PrepareStrategy) -> PrepareParams {
        switch strategy {
        case .phoneCode:
            return .init(strategy: .phoneCode)
        }
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
    
}

extension PhoneNumber {
    
    @MainActor
    public func prepareVerification(strategy: PrepareStrategy) async throws {
        let params = prepareParams(for: strategy)
        let request = APIEndpoint
            .v1
            .me
            .phoneNumbers
            .id(id)
            .prepareVerification
            .post(params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
    @MainActor
    public func attemptVerification(strategy: AttemptStrategy) async throws {
        let params = attemptParams(for: strategy)
        let request = APIEndpoint
            .v1
            .me
            .phoneNumbers
            .id(id)
            .attemptVerification
            .post(params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
}
