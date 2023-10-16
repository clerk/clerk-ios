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
            
    let authProviders = ["tornado", "timelapse"]
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var emailAddress: String = ""
    @State private var password: String = ""
    
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
                ForEach(authProviders, id: \.self) { providerImage in
                    Button(action: {
                        print("Tapped \(providerImage)")
                    }, label: {
                        AuthProviderButton(image: providerImage, label: providerImage)
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
                    CustomTextField(title: "First name", text: $firstName)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .tint(clerkTheme.colors.primary)
                    
                    CustomTextField(title: "Last name", text: $lastName)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .tint(clerkTheme.colors.primary)
                }
                
                CustomTextField(title: "Email address", text: $emailAddress)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .tint(clerkTheme.colors.primary)
                
                CustomTextField(title: "Password", text: $password, isSecureField: true)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .tint(clerkTheme.colors.primary)
                
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
            
            signUpViewModel.step = .verify
        } catch {
            dump(error)
        }
    }
}

#Preview {
    SignUpCreateView()
}

#endif
