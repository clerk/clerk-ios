//
//  PhoneNumber.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import Factory
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
    createdAt: Date = .now,
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
    try await Container.shared.userService().createPhoneNumber(phoneNumber)
  }

  /// Deletes this phone number.
  @discardableResult @MainActor
  public func delete() async throws -> DeletedObject {
    try await Container.shared.phoneNumberService().delete(self)
  }

  /// Kick off the verification process for this phone number.
  ///
  /// An SMS message with a one-time code will be sent to the phone number value.
  @discardableResult @MainActor
  public func prepareVerification() async throws -> PhoneNumber {
    try await Container.shared.phoneNumberService().prepareVerification(self)
  }

  /// Attempts to verify this phone number, passing the one-time code that was sent as an SMS message.
  ///
  /// The code will be sent when calling the ``PhoneNumber/prepareVerification()`` method.
  @discardableResult @MainActor
  public func attemptVerification(code: String) async throws -> PhoneNumber {
    try await Container.shared.phoneNumberService().attemptVerification(self, code)
  }

  /// Marks this phone number as the default second factor for multi-factor authentication(2FA). A user can have exactly one default second factor.
  @discardableResult @MainActor
  public func makeDefaultSecondFactor() async throws -> PhoneNumber {
    try await Container.shared.phoneNumberService().makeDefaultSecondFactor(self)
  }

  /// Marks this phone number as reserved for multi-factor authentication (2FA) or not.
  /// - Parameter reserved: Pass true to mark this phone number as reserved for 2FA, or false to disable 2FA for this phone number.
  @discardableResult @MainActor
  public func setReservedForSecondFactor(reserved: Bool = true) async throws -> PhoneNumber {
    try await Container.shared.phoneNumberService().setReservedForSecondFactor(self, reserved)
  }

}

extension PhoneNumber {

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
  
  static var mockMfa: PhoneNumber {
    PhoneNumber(
      id: "2",
      phoneNumber: "+15555550101",
      reservedForSecondFactor: true,
      defaultSecondFactor: true,
      verification: .mockPhoneCodeVerifiedVerification,
      linkedTo: nil,
      backupCodes: nil
    )
  }

}
