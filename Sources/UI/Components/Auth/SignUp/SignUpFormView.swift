//
//  SignUpFormView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if canImport(UIKit)

import SwiftUI

struct SignUpFormView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    @FocusState private var focusedField: Field?
    
    @State private var emailAddress: String = ""
    @State private var phoneNumber: String = ""
    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var password: String = ""
    @State private var ticket: String = ""
    @State private var enableBiometry = true
    @State private var errorWrapper: ErrorWrapper?
    
    private enum Field {
        case emailAddress, phoneNumber, username, firstName, lastName, password, ticket
    }
    
    private var signUp: SignUp? {
        clerk.client?.signUp
    }
    
    private var nameIsEnabled: Bool {
        clerk.environment?.userSettings.config(for: .firstName)?.enabled == true ||
        clerk.environment?.userSettings.config(for: .lastName)?.enabled == true
    }
    
    private var emailIsEnabled: Bool {
        clerk.environment?.userSettings.config(for: .emailAddress)?.enabled == true
    }
    
    private var usernameEnabled: Bool {
        clerk.environment?.userSettings.config(for: .username)?.enabled == true
    }
    
    private var phoneNumberIsEnabled: Bool {
        clerk.environment?.userSettings.config(for: .phoneNumber)?.enabled == true
    }
    
    private var passwordIsEnabled: Bool {
        clerk.environment?.userSettings.instanceIsPasswordBased == true
    }
    
    var body: some View {
        VStack(spacing: 24) {
            if nameIsEnabled {
                HStack(spacing: 16) {
                    if let firstName = clerk.environment?.userSettings.config(for: .firstName), firstName.enabled {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("First name")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(clerkTheme.colors.textPrimary)
                                Spacer()
                                if !firstName.required {
                                    Text("Optional")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(clerkTheme.colors.textTertiary)
                                }
                            }
                            
                            CustomTextField(text: $firstName)
                                .textContentType(.givenName)
                                .autocorrectionDisabled(true)
                                .focused($focusedField, equals: .firstName)
                        }
                    }
                    
                    if let lastName = clerk.environment?.userSettings.config(for: .lastName), lastName.enabled {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Last name")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(clerkTheme.colors.textPrimary)
                                Spacer()
                                if !lastName.required {
                                    Text("Optional")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(clerkTheme.colors.textTertiary)
                                }
                            }

                            CustomTextField(text: $lastName)
                                .textContentType(.familyName)
                                .autocorrectionDisabled(true)
                                .focused($focusedField, equals: .lastName)
                        }
                    }
                }
            }
            
            if let username = clerk.environment?.userSettings.config(for: .username), username.enabled {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Username")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.textPrimary)
                        Spacer()
                        if !username.required {
                            Text("Optional")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(clerkTheme.colors.textTertiary)
                        }
                    }
                    
                    CustomTextField(text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .username)
                }
            }
            
            if let email = clerk.environment?.userSettings.config(for: .emailAddress), email.enabled {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Email address")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.textPrimary)
                        Spacer()
                        if !email.required {
                            Text("Optional")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(clerkTheme.colors.textTertiary)
                        }
                    }
                    
                    CustomTextField(text: $emailAddress)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .emailAddress)
                }
            }
            
            if let phoneNumber = clerk.environment?.userSettings.config(for: .phoneNumber), phoneNumber.enabled {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Phone number")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.textPrimary)
                        Spacer()
                        if !phoneNumber.required {
                            Text("Optional")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(clerkTheme.colors.textTertiary)
                        }
                    }
                    
                    PhoneNumberField(text: $phoneNumber)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .focused($focusedField, equals: .phoneNumber)
                }
            }
            
            if clerk.environment?.userSettings.instanceIsPasswordBased == true {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Password")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.textPrimary)
                        Spacer()
                    }
                    
                    PasswordInputView(password: $password)
                        .focused($focusedField, equals: .password)
                    
                    if Clerk.LocalAuth.availableBiometryType != .none {
                        HStack {
                            Toggle(isOn: $enableBiometry, label: { EmptyView() })
                                .labelsHidden()
                            
                            Text("Enable \(Clerk.LocalAuth.availableBiometryType.displayName)")
                                .font(.footnote.weight(.medium))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top)
                    }
                }
            }
            
            AsyncButton {
                await continueAction()
            } label: {
                Text("Continue")
                    .clerkStandardButtonPadding()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ClerkPrimaryButtonStyle())
            .padding(.top, 8)
        }
        .clerkErrorPresenting($errorWrapper)
    }
    
    private func continueAction() async {
        KeyboardHelpers.dismissKeyboard()
        
        do {
            try await SignUp.create(.standard(
                emailAddress: emailIsEnabled ? emailAddress : nil,
                password: passwordIsEnabled ? password : nil,
                firstName: nameIsEnabled ? firstName : nil,
                lastName: nameIsEnabled ? lastName : nil,
                username: usernameEnabled ? username : nil,
                phoneNumber: phoneNumberIsEnabled ? phoneNumber : nil
            ))
            
            guard let signUp else { throw ClerkClientError(message: "There was an error creating your sign up.") }
            
            let identifer = signUp.username ?? signUp.emailAddress ?? signUp.phoneNumber
            
            if let identifer, enableBiometry {
                try Clerk.LocalAuth.setLocalAuthCredentials(identifier: identifer, password: password)
            }
            
            if signUp.missingFields.contains(where: { $0 == Strategy.saml.stringValue }) {
                try await signUp.update(params: .init(strategy: .saml))
            }
                        
            switch signUp.nextStrategyToVerify {
            case .externalProvider, .saml:
                try await signUp.authenticateWithRedirect()
            default:
                break
            }
            
            clerkUIState.setAuthStepToCurrentStatus(for: signUp)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
}

#Preview {
    SignUpFormView()
        .padding()
}

#endif
