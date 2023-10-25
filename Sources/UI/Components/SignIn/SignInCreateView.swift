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
    
    private var enabledVerificationStrategies: Set<VerificationStrategy> {
        var strategies: Set<VerificationStrategy> = []
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
                            await signInAction(strategy: .oauth(provider))
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
                        await signInAction(strategy: .emailCode)
                    } else {
                        await signInAction(strategy: .phoneCode)
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
    
    private func signInAction(strategy: VerificationStrategy) async {
        do {
            KeyboardHelpers.dismissKeyboard()
            
            try await clerk
                .client
                .signIn
                .create(clerk.client.signIn.createParams(
                    for: strategy,
                    identifier: identifier
                ))
            
            switch strategy {
                
            case .oauth:
                guard 
                    let redirectUrl = clerk.client.signIn.firstFactorVerification?.externalVerificationRedirectUrl,
                    let url = URL(string: redirectUrl)
                else {
                    throw ClerkClientError(message: "Redirect URL not provided. Unable to start OAuth flow.")
                }
                
                let authSession = OAuthWebSession(url: url, authAction: .signIn) {
                    DispatchQueue.main.async {
                        dismiss()
                    }
                }
                authSession.start()
                
            case .emailCode:
                if clerk.client.signIn.status == .needsFirstFactor {
                    clerkUIState.presentedAuthStep = .signInFirstFactor
                    
                    try await clerk
                        .client
                        .signIn
                        .prepareFirstFactor(
                            clerk.client.signIn.prepareParams(for: strategy)
                        )
                }
                
            default:
                return
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
