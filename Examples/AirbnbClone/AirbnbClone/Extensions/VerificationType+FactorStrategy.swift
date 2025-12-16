//
//  VerificationType+FactorStrategy.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/16/25.
//

import ClerkKit

/// The verification methods supported by this app.
enum VerificationMethod {
  case emailCode
  case phoneCode

  init?(strategy: FactorStrategy) {
    switch strategy {
    case .emailCode:
      self = .emailCode
    case .phoneCode:
      self = .phoneCode
    default:
      return nil
    }
  }

  init(verificationType: SignUp.VerificationType) {
    switch verificationType {
    case .email:
      self = .emailCode
    case .phone:
      self = .phoneCode
    }
  }
}
