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
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
            
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var emailAddress: String = ""
    @State private var phoneNumber: String = ""
    @State private var password: String = ""
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case firstName, lastName, email, phoneNumber, password
    }
    
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
                Text("to continue to \(clerk.environment.displayConfig.applicationName)")
                    .font(.subheadline.weight(.light))
                    .foregroundStyle(.secondary)
            }
            
            VStack {
                ForEach(thirdPartyProviders, id: \.self) { provider in
                    AsyncButton(options: [.disableButton], action: {
                        await signUpAction(strategy: .oauth(provider))
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
                        HStack {
                            Text("First name").font(.footnote.weight(.medium))
                            Spacer()
                            Text("Optional")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        CustomTextField(text: $firstName)
                            .frame(height: 36)
                            .textContentType(.givenName)
                            .autocorrectionDisabled(true)
                            .focused($focusedField, equals: .firstName)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Last name").font(.footnote.weight(.medium))
                            Spacer()
                            Text("Optional")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        CustomTextField(text: $lastName)
                            .frame(height: 36)
                            .textContentType(.familyName)
                            .autocorrectionDisabled(true)
                            .focused($focusedField, equals: .lastName)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Email address").font(.footnote.weight(.medium))
                    CustomTextField(text: $emailAddress)
                        .frame(height: 44)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .email)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Phone number").font(.footnote.weight(.medium))
                        Spacer()
                        Text("Optional")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    PhoneNumberField(text: $phoneNumber)
                        .frame(height: 44)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .focused($focusedField, equals: .phoneNumber)
                }
                
                
                VStack(alignment: .leading) {
                    Text("Password").font(.footnote.weight(.medium))
                    CustomTextField(text: $password, isSecureField: true)
                        .frame(height: 44)
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .password)
                }
                
                AsyncButton(
                    options: [.disableButton, .showProgressView],
                    action: {
                        await signUpAction(strategy: .emailCode)
                    }
                ) {
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
                    clerk.authIsPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: {
                        clerk.presentedAuthStep = .signInCreate
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
    
    private func signUpAction(strategy: VerificationStrategy) async {
        do {
            KeyboardHelpers.dismissKeyboard()
            
            switch strategy {
                
            case .oauth(let provider):
                
                try await clerk
                    .client
                    .signUp
                    .create(.init(
                        strategy: .oauth(provider),
                        redirectUrl: "clerk://",
                        actionCompleteRedirectUrl: "clerk://"
                    ))
                
                guard
                    let verification = clerk.client.signUp.verifications.first(where: { $0.key == "external_account" })?.value,
                    let redirectUrl = verification.externalVerificationRedirectUrl,
                    let url = URL(string: redirectUrl)
                else {
                    throw ClerkClientError(message: "Redirect URL not provided. Unable to start OAuth flow.")
                }
                
                let authSession = OAuthWebSession(url: url, authAction: .signUp) {
                    DispatchQueue.main.async {
                        dismiss()
                    }
                }
                
                authSession.start()
                
            case .emailCode:
                
                try await clerk
                    .client
                    .signUp
                    .create(.init(
                        firstName: firstName.isEmpty ? nil : firstName,
                        lastName: lastName.isEmpty ? nil : lastName,
                        password: password,
                        emailAddress: emailAddress,
                        phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber
                    ))
                
                try await clerk
                    .client
                    .signUp
                    .prepareVerification(.init(strategy: .emailCode))
                
                clerk.presentedAuthStep = .signUpVerification
                
            default:
                return
            }
            
        } catch {
            dump(error)
        }
    }
}

#Preview {
    SignUpCreateView()
        .environmentObject(Clerk.mock)
}

#endif
