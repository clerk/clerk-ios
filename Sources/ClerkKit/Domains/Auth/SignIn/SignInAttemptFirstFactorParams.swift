//
//  AttemptFirstFactorStrategy.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

extension SignIn {

  /// A parameter object for attempting the first factor verification process.
  public struct AttemptFirstFactorParams: Encodable, Sendable {

    /// The verification strategy being used.
    public let strategy: String

    /// The one-time code sent to the user (if applicable).
    public var code: String?

    /// The user's password (if applicable).
    public var password: String?

    /// The user's passkey public key credential (if applicable).
    public var publicKeyCredential: String?
  }

  /// Defines the available strategies for completing the first factor verification process.
  ///
  /// Each strategy specifies a method of verifying the user during the sign-in process. The selected strategy determines how the verification will be carried out and which parameters are required.
  public enum AttemptFirstFactorStrategy: Sendable {

    /// Verification using the user's password.
    /// - Parameter password: The user's password string to be verified.
    case password(password: String)

    /// Verification using a one-time code sent to the user's email.
    /// - Parameter code: The one-time code that was sent to the user's email.
    case emailCode(code: String)

    /// Verification using a one-time code sent to the user's phone.
    /// - Parameter code: The one-time code that was sent to the user's phone.
    case phoneCode(code: String)

    /// Verification using the user's passkey.
    /// - Parameter publicKeyCredential: The user's passkey public key credential.
    case passkey(publicKeyCredential: String)

    /// Verification during password reset using a one-time code sent to the user's email.
    /// - Parameter code: The one-time code that was sent to the user's email for password reset.
    case resetPasswordEmailCode(code: String)

    /// Verification during password reset using a one-time code sent to the user's phone.
    /// - Parameter code: The one-time code that was sent to the user's phone for password reset.
    case resetPasswordPhoneCode(code: String)

    /// The parameters for the selected strategy.
    var params: AttemptFirstFactorParams {
      switch self {
      case .password(let password):
        return .init(strategy: "password", password: password)
      case .emailCode(let code):
        return .init(strategy: "email_code", code: code)
      case .phoneCode(let code):
        return .init(strategy: "phone_code", code: code)
      case .passkey(let publicKeyCredential):
        return .init(strategy: "passkey", publicKeyCredential: publicKeyCredential)
      case .resetPasswordEmailCode(let code):
        return .init(strategy: "reset_password_email_code", code: code)
      case .resetPasswordPhoneCode(let code):
        return .init(strategy: "reset_password_phone_code", code: code)
      }
    }
  }
}
