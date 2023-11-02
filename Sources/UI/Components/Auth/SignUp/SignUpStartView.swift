//
//  SignUpStartView.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignUpStartView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
            
    @State private var emailAddress: String = ""
    @State private var phoneNumber: String = ""
    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var password: String = ""
    @State private var ticket: String = ""
    
    private var thirdPartyProviders: [OAuthProvider] {
        clerk.environment.userSettings.enabledThirdPartyProviders.sorted()
    }
    
    private var signUp: SignUp {
        clerk.client.signUp
    }
    
    public var body: some View {
        ScrollView {
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
                    Text("Create your account")
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
                                await signUp(provider: provider)
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
                
                SignUpFormView()
                
                HStack(spacing: 4) {
                    Text("Have an account?")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        clerkUIState.authIsPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                            clerkUIState.presentedAuthStep = .signInStart
                        })
                    } label: {
                        Text("Sign In")
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
    
    private func signUp(provider: OAuthProvider) async {
        KeyboardHelpers.dismissKeyboard()
        do {
            try await signUp.create(.oauth(provider: provider))
            signUp.startOAuth { result in
                switch result {
                case .success: dismiss()
                case .failure(let error): dump(error)
                }
            }
        } catch {
            dump(error)
        }
    }
}

#Preview {
    SignUpStartView()
        .environmentObject(Clerk.mock)
}

#endif
