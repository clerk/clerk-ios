//
//  SignIn+ServiceParams.swift
//  Clerk
//
//  Created by Mike Pitre on 1/30/25.
//

import Foundation

extension SignIn {
  struct CreateParams: Encodable, Sendable {
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

  struct PrepareFirstFactorParams: Encodable, Sendable {
    let strategy: FactorStrategy
    let emailAddressId: String?
    let phoneNumberId: String?
    let redirectUrl: String?

    init(
      strategy: FactorStrategy,
      emailAddressId: String? = nil,
      phoneNumberId: String? = nil,
      redirectUrl: String? = nil
    ) {
      self.strategy = strategy
      self.emailAddressId = emailAddressId
      self.phoneNumberId = phoneNumberId
      self.redirectUrl = redirectUrl
    }
  }

  struct AttemptFirstFactorParams: Encodable, Sendable {
    let strategy: FactorStrategy
    let code: String?
    let password: String?
    let publicKeyCredential: String?

    init(
      strategy: FactorStrategy,
      code: String? = nil,
      password: String? = nil,
      publicKeyCredential: String? = nil
    ) {
      self.strategy = strategy
      self.code = code
      self.password = password
      self.publicKeyCredential = publicKeyCredential
    }
  }

  struct PrepareSecondFactorParams: Encodable, Sendable {
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

  struct AttemptSecondFactorParams: Encodable, Sendable {
    let strategy: FactorStrategy
    let code: String

    init(strategy: FactorStrategy, code: String) {
      self.strategy = strategy
      self.code = code
    }
  }

  struct ResetPasswordParams: Encodable, Sendable {
    let password: String
    let signOutOfOtherSessions: Bool?

    init(password: String, signOutOfOtherSessions: Bool? = nil) {
      self.password = password
      self.signOutOfOtherSessions = signOutOfOtherSessions
    }
  }

  struct GetParams: Sendable {
    let rotatingTokenNonce: String?

    init(rotatingTokenNonce: String? = nil) {
      self.rotatingTokenNonce = rotatingTokenNonce
    }
  }
}
