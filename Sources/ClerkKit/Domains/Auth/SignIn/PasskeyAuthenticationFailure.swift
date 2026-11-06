//
//  PasskeyAuthenticationFailure.swift
//  Clerk
//

package struct PasskeyAuthenticationFailure: Error {
  package enum Stage {
    case preparingFirstFactor
    case preparingSecondFactor
    case requestingAuthorization
    case attemptingFirstFactor
    case attemptingSecondFactor
  }

  package let stage: Stage
  package let underlyingError: any Error
  let blockedSignIn: SignIn?

  init(stage: Stage, underlyingError: any Error, blockedSignIn: SignIn? = nil) {
    self.stage = stage
    self.underlyingError = underlyingError
    self.blockedSignIn = blockedSignIn
  }
}
