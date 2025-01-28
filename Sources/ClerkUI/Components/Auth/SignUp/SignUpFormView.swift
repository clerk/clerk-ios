//
//  SignUpFormView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if os(iOS)

import SwiftUI
import AuthenticationServices

struct SignUpFormView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(ClerkUIState.self) private var clerkUIState
    @Environment(AuthView.Config.self) private var config
    @Environment(ClerkTheme.self) private var clerkTheme
    @FocusState private var focusedField: Field?
    @State private var errorWrapper: ErrorWrapper?
    
    @Binding var isSubmitting: Bool
    
    private enum Field {
        case emailAddress, phoneNumber, username, firstName, lastName, password
    }
        
    private var nameIsEnabled: Bool {
        clerk.environment.userSettings?.attributes["first_name"]?.enabled == true ||
        clerk.environment.userSettings?.attributes["last_name"]?.enabled == true
    }
    
    private var emailIsEnabled: Bool {
        clerk.environment.userSettings?.config(for: "email_address")?.enabled == true
    }
    
    private var usernameEnabled: Bool {
        clerk.environment.userSettings?.config(for: "username")?.enabled == true
    }
    
    private var phoneNumberIsEnabled: Bool {
        clerk.environment.userSettings?.config(for: "phone_number")?.enabled == true
    }
    
    private var passwordIsEnabled: Bool {
        clerk.environment.userSettings?.instanceIsPasswordBased == true
    }
    
    private var legalIsEnabled: Bool {
        clerk.environment.userSettings?.signUp.legalConsentEnabled == true
    }
    
    var body: some View {
        @Bindable var config = config
        
        VStack(spacing: 24) {
            if nameIsEnabled {
                HStack(spacing: 16) {
                    if let firstName = clerk.environment.userSettings?.config(for: "first_name"), firstName.enabled {
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
                    
                    if let lastName = clerk.environment.userSettings?.config(for: "last_name"), lastName.enabled {
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
            
            if let phoneNumber = clerk.environment.userSettings?.config(for: "phone_number"), phoneNumber.enabled {
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
            
            if let email = clerk.environment.userSettings?.config(for: "email_address"), email.enabled {
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
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .emailAddress)
                }
            }
            
            if let username = clerk.environment.userSettings?.config(for: "username"), username.enabled {
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
            
            if clerk.environment.userSettings?.instanceIsPasswordBased == true {
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
                }
            }
            
            VStack(spacing: 0) {
                if legalIsEnabled {
                    LegalConsentView(agreedToLegalConsent: $config.signUpLegalConsentAccepted)
                        .padding(.bottom, 20)
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
            }
            .padding(.top, 8)
        }
        .clerkErrorPresenting($errorWrapper)
    }
    
    private func continueAction() async {
        isSubmitting = true
        KeyboardHelpers.dismissKeyboard()
        await performSignUp()
        isSubmitting = false
    }
    
    private func performSignUp() async {
        do {
            var signUp: SignUp
            
            signUp = try await SignUp.create(
                strategy: .standard(
                emailAddress: emailIsEnabled ? config.signUpEmailAddress : nil,
                password: passwordIsEnabled ? config.signUpPassword : nil,
                firstName: nameIsEnabled ? config.signUpFirstName : nil,
                lastName: nameIsEnabled ? config.signUpLastName : nil,
                username: usernameEnabled ? config.signUpUsername : nil,
                phoneNumber: phoneNumberIsEnabled ? config.signUpPhoneNumber : nil
            ),
                legalAccepted: legalIsEnabled ? config.signUpLegalConsentAccepted : nil
            )
            
            if signUp.missingFields.contains(where: {
                $0 == "enterprise_sso" || $0 == "saml"
            }) {
                signUp = try await signUp.update(params: .init(
                    strategy: "enterprise_sso",
                    redirectUrl: Clerk.shared.redirectConfig.redirectUrl
                ))
            }
            
            switch signUp.nextStrategyToVerify {
            case "enterprise_sso", "saml":
                let transferFlowResult = try await signUp.authenticateWithRedirect()
                switch transferFlowResult {
                case .signIn:
                    clerkUIState.setAuthStepToCurrentSignInStatus()
                case .signUp:
                    clerkUIState.setAuthStepToCurrentSignUpStatus()
                }
                return
            default:
                break
            }
            
            clerkUIState.setAuthStepToCurrentSignUpStatus()
        } catch {
            if error.isCancelledError { return }
            errorWrapper = ErrorWrapper(error: error)
            isSubmitting = false
            dump(error)
        }
    }
    
}

#Preview {
    SignUpFormView(isSubmitting: .constant(false))
        .padding()
        .environment(ClerkUIState())
        .environment(AuthView.Config())
        .environment(ClerkTheme.clerkDefault)
}

#endif
