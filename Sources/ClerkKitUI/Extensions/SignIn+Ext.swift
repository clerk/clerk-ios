//
//  SignIn+Ext.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation

extension SignIn {
  func startingFirstFactor(prefersPassword: Bool) -> Factor? {
    prefersPassword
      ? factorWhenPasswordIsPreferred
      : factorWhenOtpIsPreferred
  }

  var availableFirstFactors: [Factor] {
    firstFactors.filter { factor in
      if case .unknown = factor.strategy { return false }
      return true
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
    if !identifier.isEmpty,
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
    if !identifier.isEmpty,
       let matchingFactor = sortedFactors.first(where: { $0.safeIdentifier == identifier })
    {
      return matchingFactor
    }
    return sortedFactors.first
  }

  func alternativeFirstFactors(currentFactor: Factor?) -> [Factor] {
    firstFactors.filter { factor in
      if case .oauth = factor.strategy { return false }
      return factor != currentFactor && factor.isResetFactor == false && factor.strategy != .enterpriseSSO && factor.strategy != .saml
    }
    .sorted(using: Factor.allStrategiesButtonsComparator)
  }

  var startingSecondFactor: Factor? {
    if let passkey = secondFactors.first(where: { $0.strategy == .passkey }) {
      return passkey
    }

    if let totp = secondFactors.first(where: { $0.strategy == .totp }) {
      return totp
    }

    if let phoneCode = secondFactors.first(where: { $0.strategy == .phoneCode }) {
      return phoneCode
    }

    if let emailCode = secondFactors.first(where: { $0.strategy == .emailCode }) {
      return emailCode
    }

    return secondFactors.first
  }

  func alternativeSecondFactors(currentFactor: Factor?) -> [Factor] {
    secondFactors.filter { $0 != currentFactor }
      .sorted(using: Factor.backupCodePrefComparator)
  }

  var resetPasswordFactor: Factor? {
    if let resetPasswordEmailFactor = identifyingFirstFactor(for: "reset_password_email_code") {
      resetPasswordEmailFactor
    } else if let resetPasswordPhoneFactor = identifyingFirstFactor(for: "reset_password_phone_code") {
      resetPasswordPhoneFactor
    } else {
      firstFactors.first(where: \.isResetFactor)
    }
  }
}

#endif
