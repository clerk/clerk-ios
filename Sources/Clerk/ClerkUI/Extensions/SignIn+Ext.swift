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
    var currentFirstFactor: Factor? {
      if let firstFactorVerification,
        let currentFirstFactor = supportedFirstFactors?.first(where: {
          $0.strategy == firstFactorVerification.strategy && $0.safeIdentifier == identifier
        })
      {
        return currentFirstFactor
      }

      return startingSignInFactor
    }

    @MainActor
    var startingSignInFactor: Factor? {
      guard let supportedFirstFactors, !supportedFirstFactors.isEmpty else {
        return nil
      }

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

    var resetPasswordStrategy: SignIn.PrepareFirstFactorStrategy? {
      guard let supportedFirstFactors else { return nil }

      if let resetPasswordEmailFactor = supportedFirstFactors.first(where: { factor in
        factor.strategy == "reset_password_email_code" && factor.safeIdentifier == identifier
      }), let emailAddressId = resetPasswordEmailFactor.emailAddressId {
        return .resetPasswordEmailCode(emailAddressId: emailAddressId)
      }

      if let resetPasswordPhoneFactor = supportedFirstFactors.first(where: { factor in
        factor.strategy == "reset_password_phone_code" && factor.safeIdentifier == identifier
      }), let phoneNumberId = resetPasswordPhoneFactor.phoneNumberId {
        return .resetPasswordPhoneCode(phoneNumberId: phoneNumberId)
      }

      return nil
    }

  }

#endif
