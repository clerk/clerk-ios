//
//  SignIn+Status.swift
//  Clerk
//

extension SignIn.Status {
  var needsContinuation: Bool {
    switch self {
    case .needsIdentifier, .needsFirstFactor, .needsSecondFactor, .needsNewPassword, .needsClientTrust, .needsProtectCheck:
      true
    case .complete, .unknown:
      false
    }
  }
}
