//
//  SignInViewState.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

#if os(iOS)

import Foundation
import SwiftUI

@Observable
final class AuthState {
  enum Destination: Hashable {
    case signInStart
    case signInFactorOne(factor: Factor)
    case signInFactorOneUseAnotherMethod(currentFactor: Factor)
    case signInFactorTwo
    case forgotPassword
    case setNewPassword
    
    @MainActor
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
        Text(verbatim: "Second Factor")
      case .forgotPassword:
        SignInFactorOneForgotPasswordView()
      case .setNewPassword:
        SignInSetNewPasswordView()
      }
    }
  }
  
  var path = NavigationPath()
  
  var identifier: String = UserDefaults.standard.string(forKey: "signInIdentifier") ?? "" {
    didSet {
      UserDefaults.standard.set(identifier, forKey: "signInIdentifier")
    }
  }
  
  var phoneNumber: String = UserDefaults.standard.string(forKey: "signInPhoneNumber") ?? "" {
    didSet {
      UserDefaults.standard.set(phoneNumber, forKey: "signInPhoneNumber")
    }
  }
  
  var password = ""
  var lastCodeSentAt: [Factor: Date] = [:]
  var newPassword = ""
  var confirmNewPassword = ""
  
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
      path.append(Destination.setNewPassword)
    case .unknown:
      return
    }
  }
}

extension EnvironmentValues {
  @Entry var authState = AuthState()
}

#endif
