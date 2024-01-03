//
//  SignUpFormView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignUpFormView: View {
    @EnvironmentObject private var clerk: Clerk
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
    @State private var errorWrapper: ErrorWrapper?
    
    private enum Field {
        case emailAddress, phoneNumber, username, firstName, lastName, password, ticket
    }
    
    private var signUp: SignUp {
        clerk.client.signUp
    }
    
    private var nameEnabled: Bool {
        clerk.environment.userSettings.enabledAttributes.contains {
            $0.key == .firstName ||
            $0.key == .lastName
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            if nameEnabled {
                HStack(spacing: 16) {
                    if let firstName = clerk.environment.userSettings.config(for: .firstName), firstName.enabled {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("First name")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(clerkTheme.colors.gray700)
                                Spacer()
                                if !firstName.required {
                                    Text("Optional")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            
                            CustomTextField(text: $firstName)
                                .textContentType(.givenName)
                                .autocorrectionDisabled(true)
                                .focused($focusedField, equals: .firstName)
                        }
                    }
                    
                    if let lastName = clerk.environment.userSettings.config(for: .lastName), lastName.enabled {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Last name")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(clerkTheme.colors.gray700)
                                Spacer()
                                if !lastName.required {
                                    Text("Optional")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.tertiary)
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
            
            if let username = clerk.environment.userSettings.config(for: .username), username.enabled {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Username")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.gray700)
                        Spacer()
                        if !username.required {
                            Text("Optional")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    CustomTextField(text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .username)
                }
            }
            
            if let email = clerk.environment.userSettings.config(for: .emailAddress), email.enabled {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Email address")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.gray700)
                        Spacer()
                        if !email.required {
                            Text("Optional")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tertiary)
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
            
            if let phoneNumber = clerk.environment.userSettings.config(for: .phoneNumber), phoneNumber.enabled {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Phone number")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.gray700)
                        Spacer()
                        if !phoneNumber.required {
                            Text("Optional")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    PhoneNumberField(text: $phoneNumber)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .focused($focusedField, equals: .phoneNumber)
                }
            }
            
            if let password = clerk.environment.userSettings.config(for: .password), password.enabled {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Password")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.gray700)
                        Spacer()
                        if !password.required {
                            Text("Optional")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    PasswordInputView(password: $password)
                        .focused($focusedField, equals: .password)
                }
            }
            
            AsyncButton {
                await continueAction()
            } label: {
                Text("Continue")
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
            try await signUp.create(.standard(
                emailAddress: emailAddress,
                password: password,
                firstName: firstName,
                lastName: lastName,
                username: username,
                phoneNumber: phoneNumber
            ))
            
            clerkUIState.presentedAuthStep = .signUpVerification
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
}

#Preview {
    SignUpFormView()
        .padding()
        .environmentObject(Clerk.mock)
}

#endif
