//
//  AuthFlow.swift
//  CustomFlows
//
//  Created by Mike Pitre on 12/15/25.
//

import Foundation

enum AuthFlow: Identifiable, CaseIterable, Hashable {
  case emailPassword
  case emailCode
  case phoneSMSOTP
  case oauthConnections
  case signInWithApple
  case emailPasswordMFA
  case enterpriseConnections
  case legalAcceptance

  var id: Self { self }

  var displayName: String {
    switch self {
    case .emailPassword:
      "Email & Password"
    case .emailCode:
      "Email Code"
    case .phoneSMSOTP:
      "Phone SMS OTP"
    case .oauthConnections:
      "Sign In with OAuth"
    case .emailPasswordMFA:
      "Email & Password with MFA"
    case .enterpriseConnections:
      "Enterprise Connections"
    case .signInWithApple:
      "Sign in with Apple"
    case .legalAcceptance:
      "Legal Acceptance"
    }
  }

  var description: String {
    switch self {
    case .emailPassword:
      "Sign up and sign in using email and password"
    case .emailCode:
      "Sign up and sign in using email verification codes"
    case .phoneSMSOTP:
      "Sign up and sign in using phone SMS codes"
    case .oauthConnections:
      "Sign in using OAuth providers"
    case .emailPasswordMFA:
      "Sign in with email, password, and MFA"
    case .enterpriseConnections:
      "Sign in using enterprise SSO"
    case .signInWithApple:
      "Sign in using Sign in with Apple"
    case .legalAcceptance:
      "Handle legal acceptance requirements"
    }
  }
}
