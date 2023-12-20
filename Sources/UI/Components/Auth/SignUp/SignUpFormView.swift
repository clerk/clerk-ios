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
    
    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("First name")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.gray700)
                        Spacer()
                        Text("Optional")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                    }
                    
                    CustomTextField(text: $firstName)
                        .textContentType(.givenName)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .firstName)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Last name")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.gray700)
                        Spacer()
                        Text("Optional")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                    }

                    CustomTextField(text: $lastName)
                        .textContentType(.familyName)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .lastName)
                }
            }
            
            VStack(alignment: .leading) {
                HStack {
                    Text("Phone number")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.gray700)
                    Spacer()
                    Text("Optional")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
                
                PhoneNumberField(text: $phoneNumber)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .focused($focusedField, equals: .phoneNumber)
            }
            
            VStack(alignment: .leading) {
                Text("Email address")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(clerkTheme.colors.gray700)
                
                CustomTextField(text: $emailAddress)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .emailAddress)
            }
            
            VStack(alignment: .leading) {
                Text("Password")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(clerkTheme.colors.gray700)
                
                PasswordInputView(password: $password)
                    .focused($focusedField, equals: .password)
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
            try await signUp.create(.emailCode(
                emailAddress: emailAddress,
                password: password,
                firstName: firstName,
                lastName: lastName,
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
}

#endif
