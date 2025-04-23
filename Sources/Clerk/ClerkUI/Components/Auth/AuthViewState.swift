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
  enum Destination: Hashable {
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
  
  var path = NavigationPath()
  var identifier: String = ""
  var password: String = ""
  
  @MainActor
  func setToStepForStatus(signIn: SignIn) {
    switch signIn.status {
    case .complete:
      return
    case .needsIdentifier:
      path = NavigationPath()
    case .needsFirstFactor:
      guard let factor = signIn.startingSignInFactor else {
        path = NavigationPath()
        return
      }
      path.append(Destination.signInFactorOne(factor: factor))
    case .needsSecondFactor:
      path.append(Destination.signInFactorTwo)
    case .needsNewPassword:
      path.append(Destination.passwordReset)
    case .unknown:
      return
    }
  }
}
