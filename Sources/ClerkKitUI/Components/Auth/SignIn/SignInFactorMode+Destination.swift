//
//  SignInFactorMode+Destination.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit

extension SignInFactorMode {
  func destination(for factor: Factor) -> AuthView.Destination {
    switch self {
    case .firstFactor:
      .signInFactorOne(factor: factor)
    case .secondFactor:
      .signInFactorTwo(factor: factor)
    case .clientTrust:
      .signInClientTrust(factor: factor)
    }
  }

  func alternativeMethodsDestination(currentFactor: Factor) -> AuthView.Destination {
    switch self {
    case .firstFactor:
      .signInFactorOneUseAnotherMethod(currentFactor: currentFactor)
    case .secondFactor:
      .signInFactorTwoUseAnotherMethod(currentFactor: currentFactor)
    case .clientTrust:
      .signInClientTrustUseAnotherMethod(currentFactor: currentFactor)
    }
  }
}

#endif
