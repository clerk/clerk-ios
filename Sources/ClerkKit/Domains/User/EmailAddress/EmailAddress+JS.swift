import ClerkSnapshots
import Foundation

extension EmailAddress {
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
  public func sendCode() async throws -> EmailAddress {
    try await Clerk.js(
      .userResource(.emailAddresses, id: ClerkJSResourceID(id)),
      EmailAddressJSCall.prepareVerification(
        PrepareEmailAddressVerificationParams(strategy: .emailCode)
      ),
      as: EmailAddress.self
    )
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
  public func verifyCode(_ code: String) async throws -> EmailAddress {
    try await Clerk.js(
      .userResource(.emailAddresses, id: ClerkJSResourceID(id)),
      EmailAddressJSCall.attemptVerification(AttemptEmailAddressVerificationParams(code: code)),
      as: EmailAddress.self
    )
  }

  /// Deletes this email address.
  @discardableResult @MainActor
  public func destroy() async throws -> DeletedObject {
    try await Clerk.js(
      .userResource(.emailAddresses, id: ClerkJSResourceID(id)),
      EmailAddressJSCall.destroy,
      as: DeletedObject.self
    )
  }
}
