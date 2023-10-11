//
//  SignInCreateView.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if !os(macOS)

import SwiftUI

struct SignInCreateView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject var signInViewModel: SignInView.Model
    
    public init() {}
    
    @State private var emailAddress: String = ""
    let authProviders = ["tornado", "timelapse"]
    
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
                CustomTextField(title: "Email address", text: $emailAddress)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .tint(Color("clerkPurple", bundle: .module))
                AsyncButton(options: [.disableButton, .showProgressView], action: signInAction) {
                    Text("CONTINUE")
                        .font(.caption2.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .foregroundStyle(.white)
                        .background(Color("clerkPurple", bundle: .module))
                        .clipShape(.rect(cornerRadius: 8, style: .continuous))
                }
            }
            
            HStack {
                HStack(spacing: 4) {
                    Text("No account?")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        print("Sign Up Tapped")
                    } label: {
                        Text("Sign Up")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color("clerkPurple", bundle: .module))
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
        .padding(30)
        .background(.background)
    }
    
    private func signInAction() async {
        do {
            try await clerk
                .client
                .signIn
                .create(.init(identifier: emailAddress))
            
            try await clerk
                .client
                .signIn
                .prepareFirstFactor(.init(
                    emailAddressId: clerk.client.signIn.supportedFirstFactors.first(where: { $0.strategy == VerificationStrategy.emailCode.stringValue })?.emailAddressId,
                    strategy: .emailCode
                ))
            
            signInViewModel.step = .firstFactor
        } catch {
            dump(error)
        }
    }
}

struct SignInCreateView_Previews: PreviewProvider {
    static var previews: some View {
        SignInCreateView()
            .environmentObject(Clerk.mock)
    }
}

#endif
