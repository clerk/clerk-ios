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
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var emailAddressOrUsername: String = ""
    @State private var phoneNumber: String = ""
    @State private var displayingEmailOrUsernameEntry = true
    @State private var errorWrapper: ErrorWrapper?
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case emailOrUsername, phoneNumber
    }
    
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
    
    // returns true if email OR username is used for sign in AND phone number is used for sign in
    private var showPhoneNumberToggle: Bool {
        guard let environment = clerk.environment else { return false }
        return (environment.userSettings.firstFactorAttributes.contains { $0.key == .emailAddress } ||
        environment.userSettings.firstFactorAttributes.contains { $0.key == .username }) &&
        environment.userSettings.firstFactorAttributes.contains { $0.key == .phoneNumber }
    }
    
    // returns true if phone number is enabled, and both email and username are NOT
    private var shouldDefaultToPhoneNumber: Bool {
        guard let environment = clerk.environment else { return false }
        return environment.userSettings.firstFactorAttributes.contains { $0.key == .phoneNumber } &&
        (environment.userSettings.firstFactorAttributes.contains(where: { $0.key == .emailAddress }) == false &&
        environment.userSettings.firstFactorAttributes.contains(where: { $0.key == .username }) == false)
    }
    
    private var emailOrUsernameLabel: String {
        var stringComponents = [String]()
        if (clerk.environment?.userSettings.firstFactorAttributes ?? [:]).contains(where: { $0.key == .emailAddress }) {
            stringComponents.append("email address")
        }
        
        if (clerk.environment?.userSettings.firstFactorAttributes ?? [:]).contains(where: { $0.key == .username }) {
            stringComponents.append("username")
        }
        
        let string = stringComponents.joined(separator: " or ")
        return string
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
                        CustomTextField(text: $emailAddressOrUsername)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .focused($focusedField, equals: .emailOrUsername)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    } else {
                        PhoneNumberField(text: $phoneNumber)
                            .focused($focusedField, equals: .phoneNumber)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .onChange(of: displayingEmailOrUsernameEntry) { showingEmail in
                    if focusedField != nil {
                        focusedField = showingEmail ? .emailOrUsername : .phoneNumber
                    }
                }
            }
            
            AsyncButton {
                await signInAction(
                    strategy: .identifier(displayingEmailOrUsernameEntry ? emailAddressOrUsername : phoneNumber)
                )
            } label: {
                Text("Continue")
                    .clerkStandardButtonPadding()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ClerkPrimaryButtonStyle())
            .padding(.top, 8)
            
            if Clerk.LocalAuth.displayLocalAuthOption {
                AsyncButton {
                    do {
                        let creds = try Clerk.LocalAuth.getLocalAuthCredentials()
                        await signInAction(strategy: .identifier(creds.identifier, password: creds.password))
                    } catch {
                        errorWrapper = ErrorWrapper(error: error)
                    }
                } label: {
                    Image(systemName: Clerk.LocalAuth.availableBiometryType.systemImageName ?? "faceid")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .tint(.secondary)
                }
                .padding(.vertical)
            }
        }
        .clerkErrorPresenting($errorWrapper)
        .task(id: clerk.environment?.userSettings) {
            displayingEmailOrUsernameEntry = !shouldDefaultToPhoneNumber
        }
    }
    
    private func signInAction(strategy: SignIn.CreateStrategy) async {
        do {
            KeyboardHelpers.dismissKeyboard()
            try await SignIn.create(strategy: strategy)
            
            if let prepareStrategy = signIn?.currentFirstFactor?.strategyEnum?.signInPrepareStrategy {
                try await signIn?.prepareFirstFactor(for: prepareStrategy)
                
                // If the prepare function resulted in a verification with an external verification url,
                // trigger the external auth flow
                if signIn?.firstFactorVerification?.status == .unverified, signIn?.firstFactorVerification?.externalVerificationRedirectUrl != nil {
                    if signIn?.firstFactorVerification?.strategyEnum == .externalProvider(.apple) {
                        try await SignIn.signInWithApple()
                    } else {
                        try await signIn?.authenticateWithRedirect()
                    }
                }
            }
            
            clerkUIState.setAuthStepToCurrentStatus(for: signIn)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
}

#Preview {
    SignInFormView()
        .padding()
        .environmentObject(ClerkUIState())
}

#endif
