//
//  EmailAddress.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import Foundation

/// The `EmailAddress` object is a model around an email address.
///
/// Email addresses are used to provide identification for users.
///
/// Email addresses must be verified to ensure that they can be assigned to their rightful owners.
/// The `EmailAddress` object holds all necessary state around the verification process.
///
/// The verification process always starts with the ``EmailAddress/sendCode()`` method,
/// which will send a one-time verification code via an email message.
///
/// The second and final step involves an attempt to complete the verification by calling the ``EmailAddress/verifyCode(_:)`` method,
/// passing the one-time code as a parameter.
public struct EmailAddress: Codable, Equatable, Hashable, Identifiable, Sendable {
  /// The unique identifier for this email address.
  public var id: String

  /// The value of this email address.
  public var emailAddress: String

  /// An object holding information on the verification of this email address.
  public var verification: Verification?

  /// An array of objects containing information about any identifications
  /// that might be linked to this email address.
  public var linkedTo: [JSON]?

  /// The date the email was created.
  public var createdAt: Date

  public init(
    id: String,
    emailAddress: String,
    verification: Verification? = nil,
    linkedTo: [JSON]? = nil,
    createdAt: Date = .now
  ) {
    self.id = id
    self.emailAddress = emailAddress
    self.verification = verification
    self.linkedTo = linkedTo
    self.createdAt = createdAt
  }
}

public extension EmailAddress {
  @MainActor
  private var emailAddressService: any EmailAddressServiceProtocol { Clerk.shared.dependencies.emailAddressService }

  /// Sends a verification code to this email address.
  ///
  /// An email message with a one-time code or an email link will be sent to the email address box.
  ///
  /// - Returns: ``EmailAddress``
  /// - Throws: An error if sending the code fails.
  ///
  /// Example usage:
  /// ```swift
  /// let emailAddress = try await emailAddress.sendCode()
  /// ```
  @discardableResult @MainActor
  func sendCode() async throws -> EmailAddress {
    try await emailAddressService.prepareVerification(emailAddressId: id, strategy: .emailCode)
  }

  /// Attempts to verify this email address, passing the one-time code that was sent as an email message.
  /// The code will be sent when calling the ``EmailAddress/sendCode()`` method.
  ///
  /// - Parameters:
  ///   - code: The verification code entered by the user.
  /// - Returns: ``EmailAddress``
  /// - Throws: An error if the verification attempt fails.
  ///
  /// Example usage:
  /// ```swift
  /// let emailAddress = try await emailAddress.verifyCode("123456")
  /// ```
  @discardableResult @MainActor
  func verifyCode(_ code: String) async throws -> EmailAddress {
    try await emailAddressService.attemptVerification(emailAddressId: id, strategy: .emailCode(code: code))
  }

  /// Deletes this email address.
  @discardableResult @MainActor
  func destroy() async throws -> DeletedObject {
    try await emailAddressService.destroy(emailAddressId: id)
  }
}
