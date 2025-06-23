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

    init(mode: AuthView.Mode = .signInOrUp) {
      self.mode = mode
    }

    var path: [AuthView.Destination] = []

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

    let mode: AuthView.Mode
    var password = ""
    var lastCodeSentAt: [String: Date] = [:]
    var newPassword = ""
    var confirmNewPassword = ""
    var backupCode = ""

    @MainActor
    func setToStepForStatus(signIn: SignIn) {
      switch signIn.status {
      case .complete:
        return
      case .needsIdentifier:
        path = []
      case .needsFirstFactor:
        guard let factor = signIn.startingFirstFactor else {
          path = []
          return
        }
        path.append(AuthView.Destination.signInFactorOne(factor: factor))
      case .needsSecondFactor:
        guard let factor = signIn.startingSecondFactor else {
          path = []
          return
        }

        path.append(AuthView.Destination.signInFactorTwo(factor: factor))
      case .needsNewPassword:
        path.append(AuthView.Destination.setNewPassword)
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
        if let firstFieldToVerify = signUp.firstFieldToVerify {
          switch firstFieldToVerify {
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
        } else if let nextFieldToCollect = nextFieldToCollect(signUp: signUp) {
          switch nextFieldToCollect {
          case "password":
            path.append(AuthView.Destination.signUpCollectField(.password))
          case "email_address":
            path.append(AuthView.Destination.signUpCollectField(.emailAddress))
          case "phone_number":
            path.append(AuthView.Destination.signUpCollectField(.phoneNumber))
          case "username":
            path.append(AuthView.Destination.signUpCollectField(.username))
          default:
            path.append(AuthView.Destination.signUpCompleteProfile)
          }
        }
      case .complete:
        return
      case .unknown:
        return
      }
    }

    func nextFieldToCollect(signUp: SignUp) -> String? {
      for individuallyCollectableField in signUp.individuallyCollectableFields {
        let alreadyTriedToCollect = path.contains { destination in
          if case .signUpCollectField(let field) = destination {
            return individuallyCollectableField == field.rawValue
          }
          return false
        }

        if !alreadyTriedToCollect && signUp.collectableFields.contains(individuallyCollectableField) && !signUp.fieldWasCollected(field: individuallyCollectableField) {
          return individuallyCollectableField
        }
      }
      return nil
    }
  }

  extension EnvironmentValues {
    @Entry var authState = AuthState()
  }

#endif
