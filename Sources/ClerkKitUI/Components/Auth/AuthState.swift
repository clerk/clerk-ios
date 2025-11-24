//
//  AuthState.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

#if os(iOS)

import ClerkKit
import Foundation
import SwiftUI

@Observable
final class AuthState {
  init(mode: AuthView.Mode = .signInOrUp) {
    self.mode = mode
  }

  var path: [AuthView.Destination] = []
  let mode: AuthView.Mode
  var lastCodeSentAt: [String: Date] = [:]

  // Auth Start Fields
  var authStartIdentifier: String = UserDefaults.standard.string(forKey: "authStartIdentifier") ?? "" {
    didSet {
      UserDefaults.standard.set(authStartIdentifier, forKey: "authStartIdentifier")
    }
  }

  var authStartPhoneNumber: String = UserDefaults.standard.string(forKey: "authStartPhoneNumber") ?? "" {
    didSet {
      UserDefaults.standard.set(authStartPhoneNumber, forKey: "authStartPhoneNumber")
    }
  }

  // Sign In Fields
  var signInPassword = ""
  var signInNewPassword = ""
  var signInConfirmNewPassword = ""
  var signInBackupCode = ""

  // Sign Up Fields
  var signUpFirstName = ""
  var signUpLastName = ""
  var signUpPassword = ""
  var signUpUsername = ""
  var signUpEmailAddress = ""
  var signUpPhoneNumber = ""
  var signUpLegalAccepted = false

  @MainActor
  func setToStepForStatus(signIn: SignIn) {
    switch signIn.status {
    case .complete:
      return
    case .needsIdentifier:
      path = []
    case .needsFirstFactor:
      guard let factor = signIn.startingFirstFactor else {
        path.append(AuthView.Destination.getHelp(.signIn))
        return
      }
      path.append(AuthView.Destination.signInFactorOne(factor: factor))
    case .needsSecondFactor:
      guard let factor = signIn.startingSecondFactor else {
        path.append(AuthView.Destination.getHelp(.signIn))
        return
      }

      path.append(AuthView.Destination.signInFactorTwo(factor: factor))
    case .needsNewPassword:
      path.append(AuthView.Destination.signInSetNewPassword)
    case .unknown:
      return
    }
  }

  @MainActor
  func setToStepForStatus(signUp: SignUp) {
    switch signUp.status {
    case .abandoned:
      path = []
    case .missingRequirements:
      handleMissingRequirements(signUp: signUp)
    case .complete, .unknown:
      return
    }
  }

  @MainActor
  private func handleMissingRequirements(signUp: SignUp) {
    if let firstFieldToVerify = signUp.firstFieldToVerify {
      handleFieldToVerify(signUp: signUp, field: firstFieldToVerify)
    } else if let nextFieldToCollect = signUp.firstFieldToCollect {
      handleFieldToCollect(signUp: signUp, field: nextFieldToCollect)
    }
  }

  @MainActor
  private func handleFieldToVerify(signUp: SignUp, field: String) {
    switch field {
    case "email_address":
      guard let emailAddress = signUp.emailAddress else {
        path = []
        return
      }
      path.append(AuthView.Destination.signUpCode(.email(emailAddress)))
    case "phone_number":
      guard let phoneNumber = signUp.phoneNumber else {
        path = []
        return
      }
      path.append(AuthView.Destination.signUpCode(.phone(phoneNumber)))
    default:
      path = []
    }
  }

  @MainActor
  private func handleFieldToCollect(signUp: SignUp, field: String) {
    switch field {
    case "password":
      path.append(AuthView.Destination.signUpCollectField(.password))
    case "email_address":
      path.append(AuthView.Destination.signUpCollectField(.emailAddress))
    case "phone_number":
      path.append(AuthView.Destination.signUpCollectField(.phoneNumber))
    case "username":
      path.append(AuthView.Destination.signUpCollectField(.username))
    default:
      if signUp.canCompleteProfileHandleMissingFields {
        path.append(AuthView.Destination.signUpCompleteProfile)
      } else {
        path.append(AuthView.Destination.getHelp(.signUp))
      }
    }
  }
}

#endif
