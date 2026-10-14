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

  /// Whether the alternative methods screen would offer anything besides `currentFactor`.
  func showsUseAnotherMethod(signIn: SignIn?, currentFactor: Factor, socialProviders: [OAuthProvider]) -> Bool {
    switch self {
    case .firstFactor:
      signIn?.alternativeFirstFactors(currentFactor: currentFactor).isEmpty == false || !socialProviders.isEmpty
    case .secondFactor, .clientTrust:
      signIn?.alternativeSecondFactors(currentFactor: currentFactor).isEmpty == false
    }
  }
}

#endif
