//
//  SignInCreateView.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInCreateView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case email, phoneNumber
    }
    
    public init() {}
    
    @State private var emailAddress: String = ""
    @State private var phoneNumber: String = ""
    @State private var displayingEmailEntry = true
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    private var enabledVerificationStrategies: Set<Strategy> {
        var strategies: Set<Strategy> = []
        clerk.environment.userSettings.enabledAttributes.forEach { attribute in
            strategies.formUnion(attribute.verificationStrategies)
        }
        return strategies
    }
    
    private var thirdPartyProviders: [OAuthProvider] {
        clerk.environment
            .userSettings
            .enabledThirdPartyProviders
            .sorted()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack(spacing: 6) {
                Image("clerk-logomark", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                Text("clerk")
                    .font(.title3.weight(.semibold))
            }
            .font(.title3.weight(.medium))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Sign in")
                    .font(.title2.weight(.semibold))
                Text("to continue to \(clerk.environment.displayConfig.applicationName)")
                    .font(.subheadline.weight(.light))
                    .foregroundStyle(.secondary)
            }
            
            LazyVGrid(
                columns: Array(repeating: .init(.flexible()), count: min(thirdPartyProviders.count, thirdPartyProviders.count <= 2 ? 1 : 6)),
                alignment: .leading,
                content: {
                    ForEach(thirdPartyProviders, id: \.self) { provider in
                        AsyncButton(options: [.disableButton], action: {
                            await signInAction(strategy: .oauth(provider: provider))
                        }, label: {
                            AuthProviderButton(provider: provider, style: thirdPartyProviders.count <= 2 ? .regular : .compact)
                                .font(.footnote)
                        })
                        .buttonStyle(.plain)
                    }
                }
            )
            
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(.quaternary)
                Text("or")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(.quaternary)
                
            }
            
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
                            .frame(height: 44)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .focused($focusedField, equals: .email)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    } else {
                        PhoneNumberField(text: $phoneNumber)
                            .focused($focusedField, equals: .phoneNumber)
                            .frame(height: 44)
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: {
                        clerkUIState.presentedAuthStep = .signUpCreate
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
    
    private var identifier: String {
        displayingEmailEntry ? emailAddress : phoneNumber
    }
            
    private func signInAction(strategy: SignIn.CreateStrategy) async {
        do {
            KeyboardHelpers.dismissKeyboard()
            try await signIn.create(strategy)
            
            switch strategy {
                
            case .oauth:
                signIn.startOAuth { result in
                    switch result {
                    case .success: dismiss()
                    case .failure(let error): dump(error)
                    }
                }
                
            case .emailCode:
                try await signIn.prepareFirstFactor(.emailCode)
                clerkUIState.presentedAuthStep = .signInFirstFactor
                
            case .phoneCode:
                try await signIn.prepareFirstFactor(.phoneCode)
                clerkUIState.presentedAuthStep = .signInFirstFactor
                
            case .transfer:
                break
            }
            
        } catch {
            dump(error)
        }
    }
}

#Preview {
    SignInCreateView()
        .environmentObject(Clerk.mock)
}

#endif
