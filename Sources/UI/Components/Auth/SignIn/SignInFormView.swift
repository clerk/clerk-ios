//
//  SignInFormView.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInFormView: View {
    @EnvironmentObject private var clerk: Clerk
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
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    // returns true if email OR username is used for sign in AND phone number is used for sign in
    private var showPhoneNumberToggle: Bool {
        (clerk.environment.userSettings.firstFactorAttributes.contains { $0.key == .emailAddress } ||
        clerk.environment.userSettings.firstFactorAttributes.contains { $0.key == .username }) &&
        clerk.environment.userSettings.firstFactorAttributes.contains { $0.key == .phoneNumber }
    }
    
    // returns true if phone number is enabled, and both email and username are NOT
    private var shouldDefaultToPhoneNumber: Bool {
        clerk.environment.userSettings.firstFactorAttributes.contains { $0.key == .phoneNumber } &&
        (clerk.environment.userSettings.firstFactorAttributes.contains(where: { $0.key == .emailAddress }) == false &&
        clerk.environment.userSettings.firstFactorAttributes.contains(where: { $0.key == .username }) == false)
    }
    
    private var emailOrUsernameLabel: String {
        var stringComponents = [String]()
        if clerk.environment.userSettings.firstFactorAttributes.contains(where: { $0.key == .emailAddress }) {
            stringComponents.append("email address")
        }
        
        if clerk.environment.userSettings.firstFactorAttributes.contains(where: { $0.key == .username }) {
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
                        .foregroundStyle(clerkTheme.colors.gray700)
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
                            .textContentType(.emailAddress)
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
                if displayingEmailOrUsernameEntry {
                    await signInAction(strategy: .emailCode(email: emailAddressOrUsername))
                } else {
                    await signInAction(strategy: .phoneCode(phoneNumber: phoneNumber))
                }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ClerkPrimaryButtonStyle())
            .padding(.top, 8)
        }
        .clerkErrorPresenting($errorWrapper)
        .task(id: clerk.environment.userSettings) {
            displayingEmailOrUsernameEntry = !shouldDefaultToPhoneNumber
        }
    }
    
    private func signInAction(strategy: SignIn.CreateStrategy) async {
        do {
            KeyboardHelpers.dismissKeyboard()
            try await signIn.create(strategy)
            
            let startingFactorStrategy = signIn.startingSignInFactor(preferredStrategy: clerk.environment.displayConfig.preferredSignInStrategy)?.verificationStrategy
            
            if startingFactorStrategy == .password {
                clerkUIState.presentedAuthStep = .signInPassword
            } else {
                if let prepareStrategy = startingFactorStrategy?.signInPrepareStrategy {
                    try await signIn.prepareFirstFactor(prepareStrategy)
                    clerkUIState.presentedAuthStep = .signInFactorOneVerify
                } else {
                    throw ClerkClientError(message: "Unable to determine the first factor strategy.")
                }
            }
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
}

#Preview {
    SignInFormView()
        .padding()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
