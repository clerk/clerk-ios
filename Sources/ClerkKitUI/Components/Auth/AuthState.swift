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
                path.append(AuthView.Destination.signInGetHelp)
                return
            }
            path.append(AuthView.Destination.signInFactorOne(factor: factor))
        case .needsSecondFactor:
            guard let factor = signIn.startingSecondFactor else {
                path.append(AuthView.Destination.signInGetHelp)
                return
            }

            path.append(AuthView.Destination.signInFactorTwo(factor: factor))
        case .needsNewPassword:
            path.append(AuthView.Destination.signInSetNewPassword)
        case .needsClientTrust:
            guard let factor = signIn.startingSecondFactor else {
                path.append(AuthView.Destination.signInGetHelp)
                return
            }
            path.append(AuthView.Destination.signInClientTrust(factor: factor))
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
            } else if let nextFieldToCollect = signUp.firstFieldToCollect {
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
}

extension EnvironmentValues {
    @Entry var authState = AuthState()
}

#endif
