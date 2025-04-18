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
  enum FlowStep {
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
  
  var flowStep = FlowStep.signInStart
  var identifier: String = ""
  var password: String = ""
  
  func setToStepForStatus(signIn: SignIn) {
    switch signIn.status {
    case .complete:
      return
    case .needsIdentifier:
      flowStep = .signInStart
    case .needsFirstFactor:
      flowStep = .signInFirstFactor
    case .needsSecondFactor:
      flowStep = .signInSecondFactor
    case .needsNewPassword:
      flowStep = .passwordReset
    case .unknown:
      return
    }
  }
}
