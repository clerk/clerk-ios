//
//  SignUpCreateView.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignUpCreateView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject var signUpViewModel: SignUpView.Model
    @Environment(\.clerkTheme) private var clerkTheme
            
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var emailAddress: String = ""
    @State private var password: String = ""
    
    private var thirdPartyProviders: [OAuthProvider] {
        clerk.environment.userSettings.enabledThirdPartyProviders.sorted()
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
                Text("Create your account")
                    .font(.title2.weight(.semibold))
                Text("to continue to Clerk")
                    .font(.subheadline.weight(.light))
                    .foregroundStyle(.secondary)
            }
            
            VStack {
                ForEach(thirdPartyProviders, id: \.self) { provider in
                    Button(action: {
                        print("Tapped \(provider.data.name)")
                    }, label: {
                        AuthProviderButton(provider: provider)
                            .font(.footnote)
                    })
                    .buttonStyle(.plain)
                }
            }
            
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
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("First name").font(.footnote.weight(.medium))
                        CustomTextField(text: $firstName)
                            .frame(height: 36)
                            .textContentType(.givenName)
                            .autocorrectionDisabled(true)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Last name").font(.footnote.weight(.medium))
                        CustomTextField(text: $lastName)
                            .frame(height: 36)
                            .textContentType(.familyName)
                            .autocorrectionDisabled(true)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Email Address").font(.footnote.weight(.medium))
                    CustomTextField(text: $emailAddress)
                        .frame(height: 44)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                
                VStack(alignment: .leading) {
                    Text("Password").font(.footnote.weight(.medium))
                    CustomTextField(text: $password, isSecureField: true)
                        .frame(height: 44)
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                
                AsyncButton(options: [.disableButton, .showProgressView], action: signUpAction) {
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
                Text("Have an account?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    clerk.signUpIsPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        clerk.signInIsPresented = true
                    }
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
    
    private func signUpAction() async {
        do {
            KeyboardHelpers.dismissKeyboard()
            
            try await clerk
                .client
                .signUp
                .create(.init(
                    firstName: firstName.isEmpty ? nil : firstName,
                    lastName: lastName.isEmpty ? nil : lastName,
                    password: password,
                    emailAddress: emailAddress
                ))
            
            try await clerk
                .client
                .signUp
                .prepareVerification(.init(strategy: .emailCode))
            
            signUpViewModel.step = .verification
        } catch {
            dump(error)
        }
    }
}

#Preview {
    SignUpCreateView()
}

#endif
