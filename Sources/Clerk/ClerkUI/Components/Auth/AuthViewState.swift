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
    case signInFactorOne(factor: Factor)
    case signInFactorOneUseAnotherMethod(currentFactor: Factor)
    case signInFactorTwo
    case passwordReset
    
    @ViewBuilder
    var view: some View {
      switch self {
      case .signInStart:
        SignInStartView()
      case .signInFactorOne(let factor):
        SignInFactorOneView(factor: factor)
      case .signInFactorOneUseAnotherMethod(let currentFactor):
        SignInFactorOneAlternativeMethodsView(currentFactor: currentFactor)
      case .signInFactorTwo:
        Text("Second Factor", bundle: .module)
      case .passwordReset:
        Text("Password Reset", bundle: .module)
      }
    }
  }
  
  var step = Step.signInStart
  var identifier: String = ""
  var password: String = ""
  
  @MainActor
  func setToStepForStatus(signIn: SignIn) {
    switch signIn.status {
    case .complete:
      return
    case .needsIdentifier:
      step = .signInStart
    case .needsFirstFactor:
      guard let factor = signIn.startingSignInFactor else {
        step = .signInStart
        return
      }
      step = .signInFactorOne(factor: factor)
    case .needsSecondFactor:
      step = .signInFactorTwo
    case .needsNewPassword:
      step = .passwordReset
    case .unknown:
      return
    }
  }
}
