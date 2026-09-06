#if os(iOS) || os(macOS)

import ClerkJSCore
import ClerkKit
import Foundation

enum JSCoreAuthMapping {
  static let identifierNotFoundCodes = [
    "form_identifier_not_found",
    "invitation_account_not_exists",
  ]

  static func factor(from factor: SignInFirstFactor) -> Factor {
    Factor(
      strategy: FactorStrategy(rawValue: factor.strategy),
      emailAddressId: factor.emailAddressId,
      phoneNumberId: factor.phoneNumberId,
      web3WalletId: factor.web3WalletId,
      enterpriseConnectionId: factor.enterpriseConnectionId,
      enterpriseConnectionName: factor.enterpriseConnectionName,
      safeIdentifier: factor.safeIdentifier,
      primary: factor.primary,
      default: factor.default
    )
  }

  static func signInStatus(from status: SignInStatus) -> ClerkKit.SignIn.Status {
    switch status {
    case .needsIdentifier:
      .needsIdentifier
    case .needsFirstFactor:
      .needsFirstFactor
    case .needsSecondFactor:
      .needsSecondFactor
    case .needsClientTrust:
      .needsClientTrust
    case .needsNewPassword:
      .needsNewPassword
    case .needsProtectCheck:
      .unknown("needs_protect_check")
    case .complete:
      .complete
    case .unknown(let value):
      .unknown(value)
    }
  }

  static func signUpStatus(from status: SignUpStatus) -> ClerkKit.SignUp.Status {
    switch status {
    case .abandoned:
      .abandoned
    case .complete:
      .complete
    case .missingRequirements:
      .missingRequirements
    case .unknown(let value):
      .unknown(value)
    }
  }

  @MainActor
  static func signIn(from handle: ClerkJSCore.Clerk.SignIn) -> ClerkKit.SignIn {
    signIn(
      id: handle.id ?? "",
      status: handle.status ?? .unknown(""),
      identifier: handle.identifier,
      firstFactors: handle.supportedFirstFactors
    )
  }

  static func signIn(
    id: String,
    status: SignInStatus,
    identifier: String?,
    firstFactors: [SignInFirstFactor]
  ) -> ClerkKit.SignIn {
    ClerkKit.SignIn(
      id: id,
      status: signInStatus(from: status),
      identifier: identifier,
      supportedFirstFactors: firstFactors.map(factor(from:))
    )
  }

  @MainActor
  static func signUp(from handle: ClerkJSCore.Clerk.SignUp) -> ClerkKit.SignUp {
    signUp(
      id: handle.id ?? "",
      status: handle.status ?? .unknown(""),
      emailAddress: handle.emailAddress,
      phoneNumber: handle.phoneNumber,
      username: handle.username,
      firstName: handle.firstName,
      lastName: handle.lastName,
      passwordEnabled: handle.hasPassword,
      missingFields: handle.missingFields,
      unverifiedFields: handle.unverifiedFields,
      requiredFields: handle.requiredFields,
      optionalFields: handle.optionalFields
    )
  }

  static func signUp(
    id: String,
    status: SignUpStatus,
    emailAddress: String?,
    phoneNumber: String?,
    username: String?,
    firstName: String? = nil,
    lastName: String? = nil,
    passwordEnabled: Bool = false,
    missingFields: [String] = [],
    unverifiedFields: [String] = [],
    requiredFields: [String] = [],
    optionalFields: [String] = []
  ) -> ClerkKit.SignUp {
    ClerkKit.SignUp(
      id: id,
      status: signUpStatus(from: status),
      requiredFields: requiredFields.map(ClerkKit.SignUp.Field.init(rawValue:)),
      optionalFields: optionalFields.map(ClerkKit.SignUp.Field.init(rawValue:)),
      missingFields: missingFields.map(ClerkKit.SignUp.Field.init(rawValue:)),
      unverifiedFields: unverifiedFields.map(ClerkKit.SignUp.Field.init(rawValue:)),
      verifications: [:],
      username: username,
      emailAddress: emailAddress,
      phoneNumber: phoneNumber,
      passwordEnabled: passwordEnabled,
      firstName: firstName,
      lastName: lastName,
      abandonAt: Date()
    )
  }

  static func isIdentifierNotFound(_ error: Error) -> Bool {
    if let apiError = error as? ClerkKit.ClerkAPIError {
      return identifierNotFoundCodes.contains(apiError.code)
    }

    let message: String = if let jsError = error as? ClerkJSCoreError, case .javascript(let text) = jsError {
      text
    } else {
      error.localizedDescription
    }

    return identifierNotFoundCodes.contains { message.contains($0) }
  }
}

#endif
