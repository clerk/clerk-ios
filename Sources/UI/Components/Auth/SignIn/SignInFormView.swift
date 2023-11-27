//
//  SignInFormView.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

import SwiftUI
import Clerk

struct SignInFormView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var emailAddress: String = ""
    @State private var phoneNumber: String = ""
    @State private var displayingEmailEntry = true
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case email, phoneNumber
    }
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    var body: some View {
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
            .animation(.snappy, value: displayingEmailEntry)
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
                    .foregroundStyle(clerkTheme.colors.primaryButtonTextColor)
                    .background(clerkTheme.colors.primary)
                    .clipShape(.rect(cornerRadius: 8, style: .continuous))
            }
        }
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
    SignInFormView()
        .padding()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}