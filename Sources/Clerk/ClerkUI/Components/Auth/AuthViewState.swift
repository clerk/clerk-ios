//
//  SignInViewState.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

import Foundation
import SwiftUI

@Observable
final class AuthState {
  enum Step {
    case signInStart
    case signInFirstFactor
    case signInSecondFactor
    case passwordReset
    
    @ViewBuilder
    var view: some View {
      switch self {
      case .signInStart:
        SignInStartView()
      case .signInFirstFactor:
        SignInFactorOneView()
      case .signInSecondFactor:
        Text("Second Factor")
      case .passwordReset:
        Text("Password Reset")
      }
    }
  }
  
  var step = Step.signInStart
  var identifier: String = ""
  var password: String = ""
  
  func setToStepForStatus(signIn: SignIn) {
    switch signIn.status {
    case .complete:
      return
    case .needsIdentifier:
      step = .signInStart
    case .needsFirstFactor:
      step = .signInFirstFactor
    case .needsSecondFactor:
      step = .signInSecondFactor
    case .needsNewPassword:
      step = .passwordReset
    case .unknown:
      return
    }
  }
}
