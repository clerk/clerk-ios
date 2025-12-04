//
//  SignUp+ServiceParams.swift
//  Clerk
//
//  Created by Mike Pitre on 1/30/25.
//

import Foundation

extension SignUp {
  struct CreateParams: Encodable, Sendable {
    let locale: String
    let emailAddress: String?
    let phoneNumber: String?
    let password: String?
    let firstName: String?
    let lastName: String?
    let username: String?
    let unsafeMetadata: JSON?
    let legalAccepted: Bool?
    let redirectUrl: String?
    let ticket: String?
    let strategy: FactorStrategy?
    let token: String?
    let transfer: Bool?

    init(
      emailAddress: String? = nil,
      phoneNumber: String? = nil,
      password: String? = nil,
      firstName: String? = nil,
      lastName: String? = nil,
      username: String? = nil,
      unsafeMetadata: JSON? = nil,
      legalAccepted: Bool? = nil,
      ticket: String? = nil,
      strategy: FactorStrategy? = nil,
      token: String? = nil,
      redirectUrl: String? = nil,
      transfer: Bool? = nil
    ) {
      locale = LocaleUtils.userLocale()
      self.emailAddress = emailAddress
      self.phoneNumber = phoneNumber
      self.password = password
      self.firstName = firstName
      self.lastName = lastName
      self.username = username
      self.unsafeMetadata = unsafeMetadata
      self.legalAccepted = legalAccepted
      self.redirectUrl = redirectUrl
      self.ticket = ticket
      self.strategy = strategy
      self.token = token
      self.transfer = transfer
    }
  }

  typealias UpdateParams = CreateParams

  struct PrepareVerificationParams: Encodable, Sendable {
    let strategy: FactorStrategy
    let emailAddressId: String?
    let phoneNumberId: String?

    init(
      strategy: FactorStrategy,
      emailAddressId: String? = nil,
      phoneNumberId: String? = nil
    ) {
      self.strategy = strategy
      self.emailAddressId = emailAddressId
      self.phoneNumberId = phoneNumberId
    }
  }

  struct AttemptVerificationParams: Encodable, Sendable {
    let strategy: FactorStrategy
    let code: String

    init(strategy: FactorStrategy, code: String) {
      self.strategy = strategy
      self.code = code
    }
  }

  struct GetParams: Sendable {
    let rotatingTokenNonce: String?

    init(rotatingTokenNonce: String? = nil) {
      self.rotatingTokenNonce = rotatingTokenNonce
    }
  }
}
