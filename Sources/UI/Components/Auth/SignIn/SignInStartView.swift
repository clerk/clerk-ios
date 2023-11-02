//
//  SignInStartView.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInStartView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case email, phoneNumber
    }
        
    @State private var emailAddress: String = ""
    @State private var phoneNumber: String = ""
    @State private var displayingEmailEntry = true
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HeaderView(
                    title: "Sign in",
                    subtitle: "to continue to \(clerk.environment.displayConfig.applicationName)"
                )
                
                SignInSocialProvidersView()
                    .onSuccess { dismiss() }
                
                OrDivider()
                
                VStack(spacing: 16) {
                    VStack {
                        HStack {
                            Text(displayingEmailEntry ? "Email address" : "Phone number")
                                .contentTransition(.identity)
                            Spacer()
                            Button {
                                displayingEmailEntry.toggle()
                            } label: {
                                Text(displayingEmailEntry ? "Use phone" : "Use email")
                                    .contentTransition(.identity)
                            }
                            .tint(clerkTheme.colors.primary)
                        }
                        .font(.footnote.weight(.medium))
                        
                        if displayingEmailEntry {
                            CustomTextField(text: $emailAddress)
                                .frame(height: 42)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .focused($focusedField, equals: .email)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        } else {
                            PhoneNumberField(text: $phoneNumber)
                                .focused($focusedField, equals: .phoneNumber)
                                .frame(height: 42)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.bouncy, value: displayingEmailEntry)
                    .onChange(of: displayingEmailEntry) { showingEmail in
                        if focusedField != nil {
                            focusedField = showingEmail ? .email : .phoneNumber
                        }
                    }
                    
                    AsyncButton(options: [.disableButton, .showProgressView], action: {
                        if displayingEmailEntry {
                            await signInAction(strategy: .emailCode(email: emailAddress))
                        } else {
                            await signInAction(strategy: .phoneCode(phoneNumber: phoneNumber))
                        }
                    }) {
                        Text("CONTINUE")
                            .font(.caption2.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .foregroundStyle(.white)
                            .background(clerkTheme.colors.primary)
                            .clipShape(.rect(cornerRadius: 8, style: .continuous))
                    }
                }
                
                HStack(spacing: 4) {
                    Text("No account?")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        clerkUIState.authIsPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                            clerkUIState.presentedAuthStep = .signUpStart
                        })
                    } label: {
                        Text("Sign Up")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.primary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Secured by ")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image("clerk-logomark", bundle: .module)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16)
                            Text("clerk")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                    
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(30)
            .background(.background)
        }
    }
    
    private var identifier: String {
        displayingEmailEntry ? emailAddress : phoneNumber
    }
            
    private func signInAction(strategy: SignIn.CreateStrategy) async {
        do {
            KeyboardHelpers.dismissKeyboard()
            try await signIn.create(strategy)
            clerkUIState.presentedAuthStep = .signInFactorOne
        } catch {
            dump(error)
        }
    }
}

#Preview {
    SignInStartView()
        .environmentObject(Clerk.mock)
}

#endif
