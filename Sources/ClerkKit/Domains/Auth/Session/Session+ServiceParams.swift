//
//  Session+ServiceParams.swift
//

import Foundation

extension Session {
  struct StartVerificationParams: Encodable {
    let level: SessionVerification.Level
  }

  struct PrepareFirstFactorVerificationParams: Encodable {
    let strategy: FactorStrategy
    let emailAddressId: String?
    let phoneNumberId: String?
    let enterpriseConnectionId: String?
    let redirectUrl: String?
    let `default`: Bool?

    init(
      strategy: FactorStrategy,
      emailAddressId: String? = nil,
      phoneNumberId: String? = nil,
      enterpriseConnectionId: String? = nil,
      redirectUrl: String? = nil,
      default: Bool? = nil
    ) {
      self.strategy = strategy
      self.emailAddressId = emailAddressId
      self.phoneNumberId = phoneNumberId
      self.enterpriseConnectionId = enterpriseConnectionId
      self.redirectUrl = redirectUrl
      self.default = `default`
    }
  }

  struct AttemptFirstFactorVerificationParams: Encodable {
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

  struct PrepareSecondFactorVerificationParams: Encodable {
    let strategy: FactorStrategy
    let phoneNumberId: String?

    init(strategy: FactorStrategy, phoneNumberId: String? = nil) {
      self.strategy = strategy
      self.phoneNumberId = phoneNumberId
    }
  }

  struct AttemptSecondFactorVerificationParams: Encodable {
    let strategy: FactorStrategy
    let code: String
  }
}
