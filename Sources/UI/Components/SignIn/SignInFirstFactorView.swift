//
//  SignInFirstFactorView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInFirstFactorView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject var signInViewModel: SignInView.Model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var otpCode = ""
    @State private var isSubmittingOTPCode = false
    private let requiredOtpCodeLength = 6
    
    @State private var identifier: String?
    @State private var userImageUrl: String?
    
    private var firstFactorStrategy: VerificationStrategy? {
        if let strategy = clerk.client.signIn.firstFactorVerification?.strategy {
            return VerificationStrategy(stringValue: strategy)
        }
        return nil
    }
    
    private var firstFactor: SignInFactor? {
        clerk.client.signIn.supportedFirstFactors
            .first(where: { $0.strategy == firstFactorStrategy?.stringValue })
    }
    
    var body: some View {
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
                Text("Check your email")
                    .font(.title2.weight(.semibold))
                Text("to continue to Clerk")
                    .font(.subheadline.weight(.light))
                    .foregroundStyle(.secondary)
            }
            
            IdentityPreviewView(
                imageUrl: userImageUrl,
                label: identifier,
                action: {
                    signInViewModel.step = .create
                }
            )
            
            VStack(alignment: .leading) {
                Text("Verification code")
                    .font(.subheadline.weight(.medium))
                    .padding(.bottom, 8)
                
                Text("Enter the verification code sent to your email address")
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.footnote.weight(.light))
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .lastTextBaseline, spacing: 20) {
                    OTPFieldView(otpCode: $otpCode)
                        .frame(maxWidth: 250)
                        .padding(.vertical)
                        .padding(.bottom)
                    
                    if isSubmittingOTPCode {
                        ProgressView()
                            .offset(y: 4)
                    }
                }
                .onChange(of: otpCode) { newValue in
                    if newValue.count == requiredOtpCodeLength {
                        Task {
                            await attemptFirstFactor()
                        }
                    }
                }
                
                AsyncButton(options: [.disableButton], action: {
                    await prepareFirstFactor()
                }, label: {
                    Text("Didn't recieve a code? Resend")
                        .font(.subheadline)
                        .foregroundStyle(clerkTheme.colors.primary)
                })
            }
            
            AsyncButton(action: {
                signInViewModel.step = .create
            }, label: {
                Text("Use another method")
                    .font(.subheadline)
                    .foregroundStyle(clerkTheme.colors.primary)
            })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(30)
        .background(.background)
        .task {
            // these need to be set just once. If they update when the client does,
            // then they disappear
            self.identifier = clerk.client.signIn.identifier
            self.userImageUrl = clerk.client.signIn.userData?.imageUrl
        }
    }
    
    private func prepareFirstFactor() async {
        do {
            guard let firstFactorStrategy else {
                throw ClerkClientError(message: "Unable to determine the verification strategy.")
            }
            
            try await clerk
                .client
                .signIn
                .prepareFirstFactor(.init(
                    emailAddressId: firstFactor?.emailAddressId,
                    strategy: firstFactorStrategy
                ))
        } catch {
            dump(error)
        }
    }
    
    private func attemptFirstFactor() async {
        isSubmittingOTPCode = true
        KeyboardHelpers.dismissKeyboard()
        
        do {
            guard let firstFactorStrategy else {
                throw ClerkClientError(message: "Unable to determine the current verification strategy.")
            }
            
            try await clerk
                .client
                .signIn
                .attemptFirstFactor(.init(
                    code: otpCode,
                    strategy: firstFactorStrategy
                ))
            
            clerk.signInIsPresented = false
        } catch {
            dump(error)
            isSubmittingOTPCode = false
        }
    }
}

#Preview {
    SignInFirstFactorView()
        .environmentObject(Clerk.mock)
}

#endif
