//
//  PasskeyAuthenticationFailure.swift
//  Clerk
//

package struct PasskeyAuthenticationFailure: Error {
  package enum Stage: String {
    case preparingFirstFactor
    case preparingSecondFactor
    case requestingAuthorization
    case attemptingFirstFactor
    case attemptingSecondFactor
  }

  package let stage: Stage
  package let underlyingError: any Error
}
