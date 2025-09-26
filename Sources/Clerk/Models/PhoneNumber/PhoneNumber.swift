//
//  PhoneNumber.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import Foundation

/// The `PhoneNumber` object describes a phone number.
///
/// Phone numbers can be used as a proof of identification for users, or simply as a means of contacting users.
///
/// Phone numbers must be verified to ensure that they can be assigned to their rightful owners. The `PhoneNumber` object
/// holds all the necessary state around the verification process.
///
/// - The verification process always starts with the ``PhoneNumber/prepareVerification()`` method, which will send a one-time verification
/// code via an SMS message.
/// - The second and final step involves an attempt to complete the verification by calling the
/// ``PhoneNumber/attemptVerification(code:)`` method, passing the one-time code as a parameter.
///
/// Finally, phone numbers can be used as part of multi-factor authentication. During sign-in, users can opt in to an extra
/// verification step where they will receive an SMS message with a one-time code. This code must be entered to complete
/// the sign-in process.
public struct PhoneNumber: Codable, Equatable, Hashable, Identifiable, Sendable {

    /// The unique identifier for this phone number.
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

    /// A list of backup codes in case of lost phone number access.
    public let backupCodes: [String]?

    /// The date when the phone number was created.
    public let createdAt: Date

    public init(
        id: String,
        phoneNumber: String,
        reservedForSecondFactor: Bool,
        defaultSecondFactor: Bool,
        verification: Verification? = nil,
        linkedTo: JSON? = nil,
        backupCodes: [String]? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.reservedForSecondFactor = reservedForSecondFactor
        self.defaultSecondFactor = defaultSecondFactor
        self.verification = verification
        self.linkedTo = linkedTo
        self.backupCodes = backupCodes
        self.createdAt = createdAt
    }
}

extension PhoneNumber {

    /// Creates a new phone number for the current user.
    /// - Parameters:
    ///     - phoneNumber: The phone number to add to the current user.
    @discardableResult @MainActor
    public static func create(_ phoneNumber: String) async throws -> PhoneNumber {
        let request = Request<ClientResponse<PhoneNumber>>.build(path: "/v1/me/phone_numbers") {
            $0.method(.post)
            $0.appendSessionIdQuery()
            $0.body(["phone_number": phoneNumber])
        }

        return try await Clerk.shared.dependencyContainer.apiClient.send(request).value.response
    }

    /// Deletes this phone number.
    @discardableResult @MainActor
    public func delete() async throws -> DeletedObject {
        let request = Request<ClientResponse<DeletedObject>>.build(path: "/v1/me/phone_numbers/\(id)") {
            $0.method(.delete)
            $0.appendSessionIdQuery()
        }

        return try await Clerk.shared.dependencyContainer.apiClient.send(request).value.response
    }

    /// Kick off the verification process for this phone number.
    ///
    /// An SMS message with a one-time code will be sent to the phone number value.
    @discardableResult @MainActor
    public func prepareVerification() async throws -> PhoneNumber {
        let request = Request<ClientResponse<PhoneNumber>>.build(path: "/v1/me/phone_numbers/\(id)/prepare_verification") {
            $0.method(.post)
            $0.appendSessionIdQuery()
            $0.body(["strategy": "phone_code"])
        }

        return try await Clerk.shared.dependencyContainer.apiClient.send(request).value.response
    }

    /// Attempts to verify this phone number, passing the one-time code that was sent as an SMS message.
    ///
    /// The code will be sent when calling the ``PhoneNumber/prepareVerification()`` method.
    @discardableResult @MainActor
    public func attemptVerification(code: String) async throws -> PhoneNumber {
        let request = Request<ClientResponse<PhoneNumber>>.build(path: "/v1/me/phone_numbers/\(id)/attempt_verification") {
            $0.method(.post)
            $0.appendSessionIdQuery()
            $0.body(["code": code])
        }

        return try await Clerk.shared.dependencyContainer.apiClient.send(request).value.response
    }

    /// Marks this phone number as the default second factor for multi-factor authentication(2FA). A user can have exactly one default second factor.
    @discardableResult @MainActor
    public func makeDefaultSecondFactor() async throws -> PhoneNumber {
        let request = Request<ClientResponse<PhoneNumber>>.build(path: "/v1/me/phone_numbers/\(id)") {
            $0.method(.patch)
            $0.appendSessionIdQuery()
            $0.body(["default_second_factor": true])
        }

        return try await Clerk.shared.dependencyContainer.apiClient.send(request).value.response
    }

    /// Marks this phone number as reserved for multi-factor authentication (2FA) or not.
    /// - Parameter reserved: Pass true to mark this phone number as reserved for 2FA, or false to disable 2FA for this phone number.
    @discardableResult @MainActor
    public func setReservedForSecondFactor(reserved: Bool = true) async throws -> PhoneNumber {
        let request = Request<ClientResponse<PhoneNumber>>.build(path: "/v1/me/phone_numbers/\(id)") {
            $0.method(.patch)
            $0.appendSessionIdQuery()
            $0.body(["reserved_for_second_factor": reserved])
        }

        return try await Clerk.shared.dependencyContainer.apiClient.send(request).value.response
    }

}

@_spi(Internal)
public extension PhoneNumber {

    static var mock: PhoneNumber {
        PhoneNumber(
            id: "1",
            phoneNumber: "+15555550100",
            reservedForSecondFactor: false,
            defaultSecondFactor: false,
            verification: .mockPhoneCodeVerifiedVerification,
            linkedTo: nil,
            backupCodes: nil
        )
    }

    static var mock2: PhoneNumber {
        PhoneNumber(
            id: "2",
            phoneNumber: "+15555550101",
            reservedForSecondFactor: false,
            defaultSecondFactor: false,
            verification: .mockPhoneCodeVerifiedVerification,
            linkedTo: nil,
            backupCodes: nil
        )
    }

    static var mockMfa: PhoneNumber {
        PhoneNumber(
            id: "3",
            phoneNumber: "+15555550102",
            reservedForSecondFactor: true,
            defaultSecondFactor: true,
            verification: .mockPhoneCodeVerifiedVerification,
            linkedTo: nil,
            backupCodes: nil
        )
    }

}
