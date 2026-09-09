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
    let preferredSignInStrategy = coreOwner?.environment.displayConfig.preferredSignInStrategy
    return preferredSignInStrategy == .password
      ? factorWhenPasswordIsPreferred
      : factorWhenOtpIsPreferred
  }

  var availableFirstFactors: [Factor] {
    supportedFirstFactors.map(Factor.init).filter { factor in
      if case .unknown = factor.strategy { return false }
      // The dedicated biometric entry checks the local key and OS capability.
      return factor.strategy != .biometricCredential
    }
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
    // Remove the current factor, reset factors, oauth factors, enterprise SSO factors, saml factors, passkey factors
    let firstFactors = supportedFirstFactors.map(Factor.init).filter { factor in
      if case .oauth = factor.strategy { return false }
      return factor != currentFactor && factor.isResetFactor == false && factor.strategy != .enterpriseSSO && factor.strategy != .saml && factor.strategy != .biometricCredential
    }

    return firstFactors.sorted(using: Factor.allStrategiesButtonsComparator)
  }

  var startingSecondFactor: Factor? {
    if let passkey = supportedSecondFactors.map(Factor.init).first(where: { $0.strategy == .passkey }) {
      return passkey
    }

    if let totp = supportedSecondFactors.map(Factor.init).first(where: { $0.strategy == .totp }) {
      return totp
    }

    if let phoneCode = supportedSecondFactors.map(Factor.init).first(where: { $0.strategy == .phoneCode }) {
      return phoneCode
    }

    if let emailCode = supportedSecondFactors.map(Factor.init).first(where: { $0.strategy == .emailCode }) {
      return emailCode
    }

    return supportedSecondFactors.map(Factor.init).first
  }

  func alternativeSecondFactors(currentFactor: Factor?) -> [Factor] {
    supportedSecondFactors.map(Factor.init).filter { $0 != currentFactor }
      .sorted(using: Factor.backupCodePrefComparator)
  }

  func identifyingFirstFactor(for strategy: String) -> Factor? {
    availableFirstFactors.first { $0.strategy.rawValue == strategy }
  }

  var resetPasswordFactor: Factor? {
    if let identifier,
       let matching = availableFirstFactors.first(where: { $0.isResetFactor && $0.safeIdentifier == identifier })
    {
      return matching
    }
    if let resetPasswordEmailFactor = identifyingFirstFactor(for: "reset_password_email_code") {
      return resetPasswordEmailFactor
    } else if let resetPasswordPhoneFactor = identifyingFirstFactor(for: "reset_password_phone_code") {
      return resetPasswordPhoneFactor
    } else {
      return availableFirstFactors.first(where: \.isResetFactor)
    }
  }
}

#endif
