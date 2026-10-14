//
//  SignIn+Ext.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation

extension SignIn {
  @MainActor
  var startingFirstFactor: Factor? {
    let preferredSignInStrategy = Clerk.shared.environment?.displayConfig.preferredSignInStrategy
    return preferredSignInStrategy == .password
      ? factorWhenPasswordIsPreferred
      : factorWhenOtpIsPreferred
  }

  var availableFirstFactors: [Factor] {
    supportedFirstFactors?.filter { factor in
      if case .unknown = factor.strategy { return false }
      return true
    } ?? []
  }

  var factorWhenPasswordIsPreferred: Factor? {
    if let passkeyFactor = availableFirstFactors.first(where: { factor in
      factor.strategy == .passkey
    }) {
      return passkeyFactor
    }

    if let passwordFactor = availableFirstFactors.first(where: { factor in
      factor.strategy == .password
    }) {
      return passwordFactor
    }

    let sortedFactors = availableFirstFactors.sorted(using: Factor.passwordPrefComparator)
    if let identifier,
       let matchingFactor = sortedFactors.first(where: { $0.safeIdentifier == identifier })
    {
      return matchingFactor
    }
    return sortedFactors.first
  }

  var factorWhenOtpIsPreferred: Factor? {
    if let passkeyFactor = availableFirstFactors.first(where: { factor in
      factor.strategy == .passkey
    }) {
      return passkeyFactor
    }

    let sortedFactors = availableFirstFactors.sorted(using: Factor.otpPrefComparator)
    if let identifier,
       let matchingFactor = sortedFactors.first(where: { $0.safeIdentifier == identifier })
    {
      return matchingFactor
    }
    return sortedFactors.first
  }

  func alternativeFirstFactors(currentFactor: Factor?) -> [Factor] {
    let firstFactors = supportedFirstFactors?.filter { factor in
      factor != currentFactor && Self.isOfferedAsAlternative(factor)
    }

    return (firstFactors ?? []).sorted(using: Factor.allStrategiesButtonsComparator)
  }

  var startingSecondFactor: Factor? {
    if let passkey = supportedSecondFactors?.first(where: { $0.strategy == .passkey }) {
      return passkey
    }

    if let totp = supportedSecondFactors?.first(where: { $0.strategy == .totp }) {
      return totp
    }

    if let phoneCode = supportedSecondFactors?.first(where: { $0.strategy == .phoneCode }) {
      return phoneCode
    }

    if let emailCode = supportedSecondFactors?.first(where: { $0.strategy == .emailCode }) {
      return emailCode
    }

    return supportedSecondFactors?.first
  }

  func alternativeSecondFactors(currentFactor: Factor?) -> [Factor] {
    (supportedSecondFactors?.filter { $0 != currentFactor && Self.isOfferedAsAlternative($0) } ?? [])
      .sorted(using: Factor.backupCodePrefComparator)
  }

  /// Whether the alternative methods screens have an option to show for `factor`.
  private static func isOfferedAsAlternative(_ factor: Factor) -> Bool {
    switch factor.strategy {
    case .phoneCode, .emailCode, .emailLink:
      factor.safeIdentifier != nil
    case .passkey, .password, .totp, .backupCode:
      true
    default:
      false
    }
  }

  var resetPasswordFactor: Factor? {
    if let resetPasswordEmailFactor = identifyingFirstFactor(for: "reset_password_email_code") {
      resetPasswordEmailFactor
    } else if let resetPasswordPhoneFactor = identifyingFirstFactor(for: "reset_password_phone_code") {
      resetPasswordPhoneFactor
    } else {
      supportedFirstFactors?.first(where: \.isResetFactor)
    }
  }
}

#endif
