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
/// - The verification process always starts with the ``PhoneNumber/sendCode()`` method, which will send a one-time verification
/// code via an SMS message.
/// - The second and final step involves an attempt to complete the verification by calling the
/// ``PhoneNumber/verifyCode(_:)`` method, passing the one-time code as a parameter.
///
/// Finally, phone numbers can be used as part of multi-factor authentication. During sign-in, users can opt in to an extra
/// verification step where they will receive an SMS message with a one-time code. This code must be entered to complete
/// the sign-in process.
public struct PhoneNumber: Codable, Equatable, Hashable, Identifiable, Sendable {
  /// The unique identifier for this phone number.
  public var id: String

  /// The value of this phone number, in E.164 format.
  public var phoneNumber: String

  /// Set to true if this phone number is reserved for multi-factor authentication (2FA). Set to false otherwise.
  public var reservedForSecondFactor: Bool

  /// Set to true if this phone number is the default second factor. Set to false otherwise. A user must have exactly one default second factor, if multi-factor authentication (2FA) is enabled.
  public var defaultSecondFactor: Bool

  /// An object holding information on the verification of this phone number.
  public var verification: Verification?

  /// An object containing information about any other identification that might be linked to this phone number.
  public var linkedTo: JSON?

  /// A list of backup codes in case of lost phone number access.
  public var backupCodes: [String]?

  /// The date when the phone number was created.
  public var createdAt: Date

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

public extension PhoneNumber {
  @MainActor
  private var phoneNumberService: any PhoneNumberServiceProtocol { Clerk.shared.dependencies.phoneNumberService }

  /// Deletes this phone number.
  @discardableResult @MainActor
  func delete() async throws -> DeletedObject {
    try await phoneNumberService.delete(phoneNumberId: id)
  }

  /// Send a verification code to this phone number.
  ///
  /// An SMS message with a one-time code will be sent to the phone number value.
  @discardableResult @MainActor
  func sendCode() async throws -> PhoneNumber {
    try await phoneNumberService.prepareVerification(phoneNumberId: id)
  }

  /// Attempts to verify this phone number, passing the one-time code that was sent as an SMS message.
  ///
  /// The code will be sent when calling the ``PhoneNumber/sendCode()`` method.
  @discardableResult @MainActor
  func verifyCode(_ code: String) async throws -> PhoneNumber {
    try await phoneNumberService.attemptVerification(phoneNumberId: id, code: code)
  }

  /// Marks this phone number as the default second factor for multi-factor authentication(2FA). A user can have exactly one default second factor.
  @discardableResult @MainActor
  func makeDefaultSecondFactor() async throws -> PhoneNumber {
    try await phoneNumberService.makeDefaultSecondFactor(phoneNumberId: id)
  }

  /// Marks this phone number as reserved for multi-factor authentication (2FA) or not.
  /// - Parameter reserved: Pass true to mark this phone number as reserved for 2FA, or false to disable 2FA for this phone number.
  @discardableResult @MainActor
  func setReservedForSecondFactor(reserved: Bool = true) async throws -> PhoneNumber {
    try await phoneNumberService.setReservedForSecondFactor(phoneNumberId: id, reserved: reserved)
  }
}
