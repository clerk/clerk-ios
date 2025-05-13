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
      guard let factor = signIn.startingFirstFactor else {
        path = NavigationPath()
        return
      }
      path.append(AuthView.Destination.signInFactorOne(factor: factor))
    case .needsSecondFactor:
      guard let factor = signIn.startingSecondFactor else {
        path = NavigationPath()
        return
      }
      
      path.append(AuthView.Destination.signInFactorTwo(factor: factor))
    case .needsNewPassword:
      path.append(AuthView.Destination.setNewPassword)
    case .unknown:
      return
    }
  }
}

extension EnvironmentValues {
  @Entry var authState = AuthState()
}

#endif
