//
//  SignUpFormView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if os(iOS)

import SwiftUI

struct SignUpFormView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @EnvironmentObject private var config: AuthView.Config
    @Environment(\.clerkTheme) private var clerkTheme
    @FocusState private var focusedField: Field?
    @State private var enableBiometry = true
    @State private var errorWrapper: ErrorWrapper?
    
    @Binding var isSubmitting: Bool
    @Binding var captchaToken: String?
    @Binding var captchaIsActive: Bool
    
    private enum Field {
        case emailAddress, phoneNumber, username, firstName, lastName, password
    }
    
    private var signUp: SignUp? {
        clerk.client?.signUp
    }
    
    private var nameIsEnabled: Bool {
        clerk.environment?.userSettings.nameIsEnabled == true
    }
    
    private var emailIsEnabled: Bool {
        clerk.environment?.userSettings.config(for: "email_address")?.enabled == true
    }
    
    private var usernameEnabled: Bool {
        clerk.environment?.userSettings.config(for: "username")?.enabled == true
    }
    
    private var phoneNumberIsEnabled: Bool {
        clerk.environment?.userSettings.config(for: "phone_number")?.enabled == true
    }
    
    private var passwordIsEnabled: Bool {
        clerk.environment?.userSettings.instanceIsPasswordBased == true
    }
    
    var body: some View {
        VStack(spacing: 24) {
            if nameIsEnabled {
                HStack(spacing: 16) {
                    if let firstName = clerk.environment?.userSettings.config(for: "first_name"), firstName.enabled {
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
                            
                            CustomTextField(text: $config.signUpFirstName)
                                .textContentType(.givenName)
                                .autocorrectionDisabled(true)
                                .focused($focusedField, equals: .firstName)
                        }
                    }
                    
                    if let lastName = clerk.environment?.userSettings.config(for: "last_name"), lastName.enabled {
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

                            CustomTextField(text: $config.signUpLastName)
                                .textContentType(.familyName)
                                .autocorrectionDisabled(true)
                                .focused($focusedField, equals: .lastName)
                        }
                    }
                }
            }
            
            if let username = clerk.environment?.userSettings.config(for: "username"), username.enabled {
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
                    
                    CustomTextField(text: $config.signUpUsername)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .username)
                }
            }
            
            if let phoneNumber = clerk.environment?.userSettings.config(for: "phone_number"), phoneNumber.enabled {
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
                    
                    PhoneNumberField(text: $config.signUpPhoneNumber)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .focused($focusedField, equals: .phoneNumber)
                }
            }
            
            if let email = clerk.environment?.userSettings.config(for: "email_address"), email.enabled {
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
                    
                    CustomTextField(text: $config.signUpEmailAddress)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .emailAddress)
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
                    
                    PasswordInputView(password: $config.signUpPassword)
                        .textContentType(.newPassword)
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
                    .opacity(isSubmitting ? 0 : 1)
                    .overlay {
                        if isSubmitting {
                            ProgressView()
                        }
                    }
                    .animation(.snappy, value: isSubmitting)
                    .clerkStandardButtonPadding()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ClerkPrimaryButtonStyle())
            .padding(.top, 8)
        }
        .clerkErrorPresenting($errorWrapper)
        .onChange(of: captchaToken) { token in
            if token != nil && isSubmitting {
                Task { await performSignUp() }
            }
        }
    }
    
    private func continueAction() async {
        isSubmitting = true
        KeyboardHelpers.dismissKeyboard()
        
        if clerk.environment?.displayConfig.botProtectionIsEnabled == true && captchaToken == nil {
            captchaIsActive = true
        } else {
            await performSignUp()
            isSubmitting = false
        }
    }
    
    private func performSignUp() async {
        do {
            try await SignUp.create(strategy: .standard(
                emailAddress: emailIsEnabled ? config.signUpEmailAddress : nil,
                password: passwordIsEnabled ? config.signUpPassword : nil,
                firstName: nameIsEnabled ? config.signUpFirstName : nil,
                lastName: nameIsEnabled ? config.signUpLastName : nil,
                username: usernameEnabled ? config.signUpUsername : nil,
                phoneNumber: phoneNumberIsEnabled ? config.signUpPhoneNumber : nil
            ), captchaToken: captchaToken)
            
            guard let signUp else { throw ClerkClientError(message: "There was an error creating your sign up.") }
            
            let identifer = signUp.username ?? signUp.emailAddress ?? signUp.phoneNumber
            
            if let identifer, enableBiometry, passwordIsEnabled {
                try Clerk.LocalAuth.setLocalAuthCredentials(identifier: identifer, password: config.signUpPassword)
            }
            
            if signUp.missingFields.contains(where: { $0 == Strategy.saml.stringValue }) {
                try await signUp.update(params: .init(strategy: Strategy.saml.stringValue))
            }
            
            switch signUp.nextStrategyToVerify {
            case .oauth, .saml:
                try await signUp.authenticateWithRedirect()
            default:
                break
            }
            
            clerkUIState.setAuthStepToCurrentStatus(for: signUp)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            isSubmitting = false
            captchaToken = nil
            captchaIsActive = false
            dump(error)
        }
    }
    
}

#Preview {
    SignUpFormView(
        isSubmitting: .constant(false),
        captchaToken: .constant(nil),
        captchaIsActive: .constant(false)
    )
    .padding()
}

#endif
