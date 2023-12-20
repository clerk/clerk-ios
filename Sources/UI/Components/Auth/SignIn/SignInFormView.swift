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
    
    @State private var emailAddress: String = ""
    @State private var phoneNumber: String = ""
    @State private var displayingEmailEntry = true
    @State private var errorWrapper: ErrorWrapper?
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case email, phoneNumber
    }
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack {
                HStack {
                    Text(displayingEmailEntry ? "Email address" : "Phone number")
                        .contentTransition(.identity)
                        .foregroundStyle(clerkTheme.colors.gray700)
                    Spacer()
                    Button {
                        displayingEmailEntry.toggle()
                    } label: {
                        Text(displayingEmailEntry ? "Use phone" : "Use email")
                            .contentTransition(.identity)
                    }
                    .tint(clerkTheme.colors.textPrimary)
                }
                .font(.footnote.weight(.medium))
                
                if displayingEmailEntry {
                    CustomTextField(text: $emailAddress)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .email)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    PhoneNumberField(text: $phoneNumber)
                        .focused($focusedField, equals: .phoneNumber)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: displayingEmailEntry)
            .onChange(of: displayingEmailEntry) { showingEmail in
                if focusedField != nil {
                    focusedField = showingEmail ? .email : .phoneNumber
                }
            }
            
            AsyncButton {
                if displayingEmailEntry {
                    await signInAction(strategy: .emailCode(email: emailAddress))
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
    }
    
    private func signInAction(strategy: SignIn.CreateStrategy) async {
        do {
            KeyboardHelpers.dismissKeyboard()
            try await signIn.create(strategy)
            
            if signIn.defaultSignInStrategy == .password {
                clerkUIState.presentedAuthStep = .signInPassword
            } else {
                if let prepareStrategy = signIn.defaultSignInStrategy?.signInPrepareStrategy {
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
