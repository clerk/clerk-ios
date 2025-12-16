//
//  PendingVerification.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit

enum PendingVerification {
  case signIn(SignIn)
  case signUp(SignUp, SignUp.VerificationType)
}
