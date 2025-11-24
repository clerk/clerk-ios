//
//  SignIn+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

#if os(iOS)

import ClerkKit
import Foundation

extension SignIn {
  @MainActor
  var startingFirstFactor: Factor? {
    let preferredSignInStrategy = Clerk.shared.environment.displayConfig?.preferredSignInStrategy

    if preferredSignInStrategy == .password {
      return factorWhenPasswordIsPreferred
    } else {
      return factorWhenOtpIsPreferred
    }
  }

  var factorWhenPasswordIsPreferred: Factor? {
    let availableFirstFactors = supportedFirstFactors?.filter { factor in
      if case .unknown = factor.strategy { return false }
      return true
    }

    if let passkeyFactor = availableFirstFactors?.first(where: { factor in
      factor.strategy == .passkey
    }) {
      return passkeyFactor
    }

    if let passwordFactor = availableFirstFactors?.first(where: { factor in
      factor.strategy == .password
    }) {
      return passwordFactor
    }

    let sortedFactors = availableFirstFactors?.sorted(using: Factor.passwordPrefComparator)

    return availableFirstFactors?.first { factor in
      factor.safeIdentifier == identifier
    } ?? sortedFactors?.first
  }

  var factorWhenOtpIsPreferred: Factor? {
    let availableFirstFactors = supportedFirstFactors?.filter { factor in
      if case .unknown = factor.strategy { return false }
      return true
    }

    if let passkeyFactor = availableFirstFactors?.first(where: { factor in
      factor.strategy == .passkey
    }) {
      return passkeyFactor
    }

    let sortedFactors = availableFirstFactors?.sorted(using: Factor.otpPrefComparator)

    return sortedFactors?.first { factor in
      factor.safeIdentifier == identifier
    } ?? sortedFactors?.first
  }

  func alternativeFirstFactors(currentFactor: Factor?) -> [Factor] {
    // Remove the current factor, reset factors, oauth factors, enterprise SSO factors, saml factors, passkey factors
    let firstFactors = supportedFirstFactors?.filter { factor in
      if case .oauth = factor.strategy { return false }
      return factor != currentFactor && factor.isResetFactor == false && factor.strategy != .enterpriseSSO && factor.strategy != .saml
    }

    return (firstFactors ?? []).sorted(using: Factor.allStrategiesButtonsComparator)
  }

  var startingSecondFactor: Factor? {
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
    (supportedSecondFactors?.filter { $0 != currentFactor } ?? [])
      .sorted(using: Factor.backupCodePrefComparator)
  }

  var resetPasswordFactor: Factor? {
    if let resetPasswordEmailFactor = identifyingFirstFactor(strategy: .resetPasswordEmailCode()) {
      resetPasswordEmailFactor
    } else if let resetPasswordPhoneFactor = identifyingFirstFactor(strategy: .resetPasswordPhoneCode()) {
      resetPasswordPhoneFactor
    } else {
      supportedFirstFactors?.first(where: \.isResetFactor)
    }
  }
}

#endif
