//
//  SignInFactorMode.swift
//  Clerk
//

#if os(iOS) || os(macOS)

enum SignInFactorMode: Hashable {
  case firstFactor
  case secondFactor
  case clientTrust

  var usesSecondFactorAPI: Bool {
    switch self {
    case .firstFactor:
      false
    case .secondFactor, .clientTrust:
      true
    }
  }

  var showsClientTrustWarning: Bool {
    self == .clientTrust
  }
}

#endif
