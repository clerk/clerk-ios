//
//  SignIn+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

#if os(iOS)

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

      // email links are not supported on iOS
      let availableFirstFactors = supportedFirstFactors?.filter { factor in
        factor.strategy != "email_link"
      }

      if let passkeyFactor = availableFirstFactors?.first(where: { factor in
        factor.strategy == "passkey"
      }) {
        return passkeyFactor
      }

      if let passwordFactor = availableFirstFactors?.first(where: { factor in
        factor.strategy == "password"
      }) {
        return passwordFactor
      }

      let sortedFactors = availableFirstFactors?.sorted(using: Factor.passwordPrefComparator)

      return availableFirstFactors?.first { factor in
        factor.safeIdentifier == identifier
      } ?? sortedFactors?.first
    }

    var factorWhenOtpIsPreferred: Factor? {

      // email links are not supported on iOS
      let availableFirstFactors = supportedFirstFactors?.filter { factor in
        factor.strategy != "email_link"
      }

      if let passkeyFactor = availableFirstFactors?.first(where: { factor in
        factor.strategy == "passkey"
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
        factor != currentFactor && factor.isResetFactor == false && !(factor.strategy).hasPrefix("oauth_") && factor.strategy != "enterprise_sso" && factor.strategy != "saml"
      }

      return (firstFactors ?? []).sorted(using: Factor.allStrategiesButtonsComparator)
    }

    var startingSecondFactor: Factor? {
      if let totp = supportedSecondFactors?.first(where: { $0.strategy == "totp" }) {
        return totp
      }

      if let phoneCode = supportedSecondFactors?.first(where: { $0.strategy == "phone_code" }) {
        return phoneCode
      }

      return supportedSecondFactors?.first
    }

    func alternativeSecondFactors(currentFactor: Factor?) -> [Factor] {
      supportedSecondFactors?.filter { $0 != currentFactor } ?? []
    }

    var resetPasswordFactor: Factor? {
      if let resetPasswordEmailFactor = identifyingFirstFactor(strategy: .resetPasswordEmailCode()) {
        return resetPasswordEmailFactor
      } else if let resetPasswordPhoneFactor = identifyingFirstFactor(strategy: .resetPasswordPhoneCode()) {
        return resetPasswordPhoneFactor
      } else {
        return nil
      }
    }

  }

#endif
