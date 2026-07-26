//
//  PasskeyAuthenticationFailure.swift
//  Clerk
//

package struct PasskeyAuthenticationFailure: Error {
  package enum Stage {
    case preparingFirstFactor
    case requestingAuthorization
    case attemptingFirstFactor
  }

  package let stage: Stage
  package let underlyingError: any Error
}
