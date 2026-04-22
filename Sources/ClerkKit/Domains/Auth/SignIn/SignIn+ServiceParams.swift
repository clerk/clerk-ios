//
//  SignIn+ServiceParams.swift
//  Clerk
//

import Foundation

extension SignIn {
  struct CreateParams: Encodable {
    let locale: String
    let identifier: String?
    let password: String?
    let strategy: FactorStrategy?
    let redirectUrl: String?
    let ticket: String?
    let token: String?
    let transfer: Bool?

    init(
      identifier: String? = nil,
      password: String? = nil,
      strategy: FactorStrategy? = nil,
      ticket: String? = nil,
      token: String? = nil,
      redirectUrl: String? = nil,
      transfer: Bool? = nil
    ) {
      locale = LocaleUtils.userLocale()
      self.identifier = identifier
      self.password = password
      self.strategy = strategy
      self.redirectUrl = redirectUrl
      self.ticket = ticket
      self.token = token
      self.transfer = transfer
    }
  }

  struct PrepareFirstFactorParams: Encodable {
    let strategy: FactorStrategy
    let emailAddressId: String?
    let phoneNumberId: String?
    let redirectUrl: String?
    let redirectUri: String?
    let codeChallenge: String?
    let codeChallengeMethod: String?

    init(
      strategy: FactorStrategy,
      emailAddressId: String? = nil,
      phoneNumberId: String? = nil,
      redirectUrl: String? = nil,
      redirectUri: String? = nil,
      codeChallenge: String? = nil,
      codeChallengeMethod: String? = nil
    ) {
      self.strategy = strategy
      self.emailAddressId = emailAddressId
      self.phoneNumberId = phoneNumberId
      self.redirectUrl = redirectUrl
      self.redirectUri = redirectUri
      self.codeChallenge = codeChallenge
      self.codeChallengeMethod = codeChallengeMethod
    }
  }

  struct AttemptFirstFactorParams: Encodable {
    let strategy: FactorStrategy
    let code: String?
    let password: String?
    let publicKeyCredential: String?
    let token: String?

    init(
      strategy: FactorStrategy,
      code: String? = nil,
      password: String? = nil,
      publicKeyCredential: String? = nil,
      token: String? = nil
    ) {
      self.strategy = strategy
      self.code = code
      self.password = password
      self.publicKeyCredential = publicKeyCredential
      self.token = token
    }
  }

  struct PrepareSecondFactorParams: Encodable {
    let strategy: FactorStrategy
    let phoneNumberId: String?
    let emailAddressId: String?

    init(
      strategy: FactorStrategy,
      phoneNumberId: String? = nil,
      emailAddressId: String? = nil
    ) {
      self.strategy = strategy
      self.phoneNumberId = phoneNumberId
      self.emailAddressId = emailAddressId
    }
  }

  struct AttemptSecondFactorParams: Encodable {
    let strategy: FactorStrategy
    let code: String
  }

  struct ResetPasswordParams: Encodable {
    let password: String
    let signOutOfOtherSessions: Bool?

    init(password: String, signOutOfOtherSessions: Bool? = nil) {
      self.password = password
      self.signOutOfOtherSessions = signOutOfOtherSessions
    }
  }

  struct GetParams {
    let rotatingTokenNonce: String?

    init(rotatingTokenNonce: String? = nil) {
      self.rotatingTokenNonce = rotatingTokenNonce
    }
  }
}
