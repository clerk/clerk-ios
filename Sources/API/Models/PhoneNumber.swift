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
public struct PhoneNumber: Codable, Equatable, Hashable, Identifiable, Sendable {
    
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
    public let linkedTo: JSON?
    
    /// A set of fresh generated Backup codes. Note that this will be populated if the feature is enabled in your instance and the user doesn't already have backup codes generated.
    public let backupCodes: [String]?
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

        #if os(iOS)
        
        if
            let region = phoneNumber.regionID,
            let country = CountryCodePickerViewController.Country(for: region, with: phoneNumberKit)
        {
            return country.flag
        }
        #endif
        
        return nil
    }
    
    func formatted(_ format: PhoneNumberFormat) -> String {
        let phoneNumberKit = Container.shared.phoneNumberKit()
        guard let phoneNumber = try? phoneNumberKit.parse(phoneNumber) else { return phoneNumber }
        return phoneNumberKit.format(phoneNumber, toType: format)
    }
    
}

extension PhoneNumber {
    
    /// Kick off the verification process for this phone number. An SMS message with a one-time code will be sent to the phone number value.
    @discardableResult @MainActor
    public func prepareVerification() async throws -> PhoneNumber {
        let request = ClerkAPI.v1.me.phoneNumbers.id(id).prepareVerification.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Attempts to verify this phone number, passing the one-time code that was sent as an SMS message. The code will be sent when calling the `PhoneNumber.prepareVerification()` method.
    @discardableResult @MainActor
    public func attemptVerification(code: String) async throws -> PhoneNumber {
        let request = ClerkAPI.v1.me.phoneNumbers.id(id).attemptVerification.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["code": code]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Marks this phone number as reserved for multi-factor authentication (2FA) or not.
    /// - Parameter reserved: Pass true to mark this phone number as reserved for 2FA, or false to disable 2FA for this phone number.
    @discardableResult @MainActor
    public func setReservedForSecondFactor(reserved: Bool = true) async throws -> PhoneNumber {
        let request = ClerkAPI.v1.me.phoneNumbers.id(id).patch(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["reserved_for_second_factor": reserved]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Deletes this phone number.
    @discardableResult @MainActor
    public func destroy() async throws -> DeletedObject {
        let request = ClerkAPI.v1.me.phoneNumbers.id(id).delete(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    @discardableResult @MainActor
    func setAsPrimary() async throws -> User {
        let request = ClerkAPI.v1.me.update(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["primary_phone_number_id": id]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
}
