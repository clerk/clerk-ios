import ClerkSnapshots
import Foundation

extension PhoneNumber {
  /// Deletes this phone number.
  @discardableResult @MainActor
  public func delete() async throws -> DeletedObject {
    try await Clerk.js(
      .userResource(.phoneNumbers, id: ClerkJSResourceID(id)),
      PhoneNumberJSCall.destroy,
      as: DeletedObject.self
    )
  }

  /// Send a verification code to this phone number.
  ///
  /// An SMS message with a one-time code will be sent to the phone number value.
  @discardableResult @MainActor
  public func sendCode() async throws -> PhoneNumber {
    try await Clerk.js(
      .userResource(.phoneNumbers, id: ClerkJSResourceID(id)),
      PhoneNumberJSCall.prepareVerification,
      as: PhoneNumber.self
    )
  }

  /// Attempts to verify this phone number, passing the one-time code that was sent as an SMS message.
  ///
  /// The code will be sent when calling the ``PhoneNumber/sendCode()`` method.
  @discardableResult @MainActor
  public func verifyCode(_ code: String) async throws -> PhoneNumber {
    try await Clerk.js(
      .userResource(.phoneNumbers, id: ClerkJSResourceID(id)),
      PhoneNumberJSCall.attemptVerification(AttemptPhoneNumberVerificationParams(code: code)),
      as: PhoneNumber.self
    )
  }

  /// Marks this phone number as the default second factor for multi-factor authentication(2FA). A user can have exactly one default second factor.
  @discardableResult @MainActor
  public func makeDefaultSecondFactor() async throws -> PhoneNumber {
    try await Clerk.js(
      .userResource(.phoneNumbers, id: ClerkJSResourceID(id)),
      PhoneNumberJSCall.makeDefaultSecondFactor,
      as: PhoneNumber.self
    )
  }

  /// Marks this phone number as reserved for multi-factor authentication (2FA) or not.
  /// - Parameter reserved: Pass true to mark this phone number as reserved for 2FA, or false to disable 2FA for this phone number.
  @discardableResult @MainActor
  public func setReservedForSecondFactor(reserved: Bool = true) async throws -> PhoneNumber {
    try await Clerk.js(
      .userResource(.phoneNumbers, id: ClerkJSResourceID(id)),
      PhoneNumberJSCall.setReservedForSecondFactor(SetReservedForSecondFactorParams(reserved: reserved)),
      as: PhoneNumber.self
    )
  }
}
