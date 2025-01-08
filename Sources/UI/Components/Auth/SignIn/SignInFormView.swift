//
//  SignInFormView.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if os(iOS)

import SwiftUI

struct SignInFormView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @EnvironmentObject private var config: AuthView.Config
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var displayingEmailOrUsernameEntry = true
    @State private var errorWrapper: ErrorWrapper?
    @Binding var isLoading: Bool
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case emailOrUsername, phoneNumber
    }
    
    var signIn: SignIn? {
        clerk.client?.signIn
    }
    
    var hasAnInProgressPasskeyAuth: Bool {
        signIn?.firstFactorVerification?.strategyEnum == .passkey &&
        signIn?.firstFactorVerification?.expireAt ?? Date.now > Date.now
    }
    
    // returns true if email OR username is used for sign in AND phone number is used for sign in
    private var showPhoneNumberToggle: Bool {
        guard let environment = clerk.environment else { return false }
        return (environment.userSettings.firstFactorAttributes.contains { $0.key == "email_address" } ||
        environment.userSettings.firstFactorAttributes.contains { $0.key == "username" }) &&
        environment.userSettings.firstFactorAttributes.contains { $0.key == "phone_number" }
    }
    
    // returns true if phone number is enabled, and both email and username are NOT
    private var shouldDefaultToPhoneNumber: Bool {
        guard let environment = clerk.environment else { return false }
        return environment.userSettings.firstFactorAttributes.contains { $0.key == "phone_number" } &&
        (environment.userSettings.firstFactorAttributes.contains(where: { $0.key == "email_address" }) == false &&
        environment.userSettings.firstFactorAttributes.contains(where: { $0.key == "username" }) == false)
    }
    
    private var emailOrUsernameLabel: String {
        var stringComponents = [String]()
        if (clerk.environment?.userSettings.firstFactorAttributes ?? [:]).contains(where: { $0.key == "email_address" }) {
            stringComponents.append("email address")
        }
        
        if (clerk.environment?.userSettings.firstFactorAttributes ?? [:]).contains(where: { $0.key == "username" }) {
            stringComponents.append("username")
        }
        
        let string = stringComponents.joined(separator: " or ")
        return string
    }
    
    private var passkeysAreEnabled: Bool {
        clerk.environment?.userSettings.config(for: "passkey")?.enabled == true
    }
    
    private var passkeyAutoFillIsEnabled: Bool {
        clerk.environment?.userSettings.passkeySettings?.allowAutofill == true
    }
        
    var body: some View {
        VStack(spacing: 24) {
            VStack {
                HStack {
                    Text(displayingEmailOrUsernameEntry ? emailOrUsernameLabel.capitalizedSentence : "Phone number")
                        .foregroundStyle(clerkTheme.colors.textPrimary)
                        .animation(nil, value: displayingEmailOrUsernameEntry)
                    Spacer()
                    
                    if showPhoneNumberToggle {
                        Button {
                            withAnimation(.snappy) {
                                displayingEmailOrUsernameEntry.toggle()
                            }
                        } label: {
                            Text(displayingEmailOrUsernameEntry ? "Use phone" : "Use \(emailOrUsernameLabel)".capitalizedSentence)
                                .frame(alignment: .trailing)
                                .animation(nil, value: displayingEmailOrUsernameEntry)
                        }
                        .tint(clerkTheme.colors.textPrimary)
                    }
                }
                .font(.footnote.weight(.medium))
                
                ZStack {
                    if displayingEmailOrUsernameEntry {
                        CustomTextField(text: $config.signInEmailAddressOrUsername)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .focused($focusedField, equals: .emailOrUsername)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    } else {
                        PhoneNumberField(text: $config.signInPhoneNumber)
                            .focused($focusedField, equals: .phoneNumber)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .onChange(of: displayingEmailOrUsernameEntry) { showingEmail in
                    if focusedField != nil {
                        focusedField = showingEmail ? .emailOrUsername : .phoneNumber
                    }
                }
                .hiddenTextField(text: $config.signInPassword, textContentType: .password)
            }
            
            if !config.signInPassword.isEmpty {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Password")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.textPrimary)
                        Spacer()
                    }
                    
                    PasswordInputView(password: $config.signInPassword)
                        .textContentType(.password)
                }
            }
            
            AsyncButton {
                await signInAction(
                    strategy: .identifier(
                        displayingEmailOrUsernameEntry ? config.signInEmailAddressOrUsername : config.signInPhoneNumber,
                        password: config.signInPassword.isEmpty ? nil : config.signInPassword
                    )
                )
            } label: {
                Text("Continue")
                    .opacity(isLoading ? 0 : 1)
                    .overlay {
                        if isLoading {
                            ProgressView()
                        }
                    }
                    .animation(.snappy, value: isLoading)
                    .clerkStandardButtonPadding()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ClerkPrimaryButtonStyle())
            .padding(.top, 8)
        }
        .animation(.default, value: config.signInPassword.isEmpty)
        .clerkErrorPresenting($errorWrapper)
        .task(id: clerk.environment?.userSettings) {
            displayingEmailOrUsernameEntry = !shouldDefaultToPhoneNumber
            
            if passkeysAreEnabled, passkeyAutoFillIsEnabled {
                await beginAutoFillAssistedPasskeySignIn()
            }
        }
        .onDisappear {
            PasskeyManager.controller?.cancel()
        }
    }
}

extension SignInFormView {
    
    private func signInAction(strategy: SignIn.CreateStrategy) async {
        do {
            KeyboardHelpers.dismissKeyboard()
            
            try await SignIn.create(strategy: strategy)
            
            if passkeysAreEnabled, signIn?.firstFactor(for: .passkey) != nil {
                do {
                    try await attemptSignInWithPasskey()
                } catch {
                    if let prepareStrategy = signIn?.currentFirstFactor?.prepareFirstFactorStrategy {
                        try await signIn?.prepareFirstFactor(for: prepareStrategy)
                    }
                }
            }
            
            clerkUIState.setAuthStepToCurrentSignInStatus()
        } catch {
            isLoading = false
            if error.isCancelledError { return }
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func beginAutoFillAssistedPasskeySignIn() async {
        do {
            if !hasAnInProgressPasskeyAuth {
                try await SignIn
                    .create(strategy: .passkey)
            }
            
            guard let signIn else { return }
            
            let credential = try await signIn
                .getCredentialForPasskey(autofill: true)
            
            isLoading = true
            
            try await signIn.attemptFirstFactor(
                for: .passkey(publicKeyCredential: credential)
            )
            
            clerkUIState.setAuthStepToCurrentSignInStatus()
            
        } catch {
            isLoading = false
            dump(error)
        }
    }
    
    private func attemptSignInWithPasskey() async throws {
        PasskeyManager.controller?.cancel()
        
        guard var signIn else { throw ClerkClientError(message: "Unable to find a current sign in.") }
        
        signIn = try await signIn
            .prepareFirstFactor(for: .passkey)
        
        let credential = try await signIn
            .getCredentialForPasskey()
        
        isLoading = true
        
        try await signIn.attemptFirstFactor(
            for: .passkey(publicKeyCredential: credential)
        )
    }
    
}

#Preview {
    SignInFormView(isLoading: .constant(false))
        .padding()
        .environmentObject(ClerkUIState())
}

#endif
