//
//  SignUp+Status.swift
//  Clerk
//

extension SignUp.Status {
  var needsContinuation: Bool {
    switch self {
    case .missingRequirements:
      true
    case .abandoned, .complete, .unknown:
      false
    }
  }
}
