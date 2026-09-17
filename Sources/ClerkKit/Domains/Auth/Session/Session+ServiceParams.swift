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
    let biometricCredentialId: String?

    private enum CodingKeys: String, CodingKey {
      case strategy
      case emailAddressId
      case phoneNumberId
      case enterpriseConnectionId
      case redirectUrl
      case biometricCredentialId = "trustedDeviceId"
    }

    init(
      strategy: FactorStrategy,
      emailAddressId: String? = nil,
      phoneNumberId: String? = nil,
      enterpriseConnectionId: String? = nil,
      redirectUrl: String? = nil,
      biometricCredentialId: String? = nil
    ) {
      self.strategy = strategy
      self.emailAddressId = emailAddressId
      self.phoneNumberId = phoneNumberId
      self.enterpriseConnectionId = enterpriseConnectionId
      self.redirectUrl = redirectUrl
      self.biometricCredentialId = biometricCredentialId
    }
  }

  struct AttemptFirstFactorVerificationParams: Encodable {
    let strategy: FactorStrategy
    let code: String?
    let password: String?
    let publicKeyCredential: String?
    let biometricCredentialId: String?
    let clientData: String?
    let signature: String?
    let algorithm: BiometricCredential.Algorithm?

    private enum CodingKeys: String, CodingKey {
      case strategy
      case code
      case password
      case publicKeyCredential
      case biometricCredentialId = "trustedDeviceId"
      case clientData
      case signature
      case algorithm
    }

    init(
      strategy: FactorStrategy,
      code: String? = nil,
      password: String? = nil,
      publicKeyCredential: String? = nil,
      biometricCredentialId: String? = nil,
      clientData: String? = nil,
      signature: String? = nil,
      algorithm: BiometricCredential.Algorithm? = nil
    ) {
      self.strategy = strategy
      self.code = code
      self.password = password
      self.publicKeyCredential = publicKeyCredential
      self.biometricCredentialId = biometricCredentialId
      self.clientData = clientData
      self.signature = signature
      self.algorithm = algorithm
    }
  }

  struct PrepareSecondFactorVerificationParams: Encodable {
    let strategy: FactorStrategy
    let phoneNumberId: String?
    let biometricCredentialId: String?

    private enum CodingKeys: String, CodingKey {
      case strategy
      case phoneNumberId
      case biometricCredentialId = "trustedDeviceId"
    }

    init(
      strategy: FactorStrategy,
      phoneNumberId: String? = nil,
      biometricCredentialId: String? = nil
    ) {
      self.strategy = strategy
      self.phoneNumberId = phoneNumberId
      self.biometricCredentialId = biometricCredentialId
    }
  }

  struct AttemptSecondFactorVerificationParams: Encodable {
    let strategy: FactorStrategy
    let code: String?
    let publicKeyCredential: String?
    let biometricCredentialId: String?
    let clientData: String?
    let signature: String?
    let algorithm: BiometricCredential.Algorithm?

    private enum CodingKeys: String, CodingKey {
      case strategy
      case code
      case publicKeyCredential
      case biometricCredentialId = "trustedDeviceId"
      case clientData
      case signature
      case algorithm
    }

    init(
      strategy: FactorStrategy,
      code: String? = nil,
      publicKeyCredential: String? = nil,
      biometricCredentialId: String? = nil,
      clientData: String? = nil,
      signature: String? = nil,
      algorithm: BiometricCredential.Algorithm? = nil
    ) {
      self.strategy = strategy
      self.code = code
      self.publicKeyCredential = publicKeyCredential
      self.biometricCredentialId = biometricCredentialId
      self.clientData = clientData
      self.signature = signature
      self.algorithm = algorithm
    }
  }
}
