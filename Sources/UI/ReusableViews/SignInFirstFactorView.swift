//
//  SignInFirstFactorView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

import SwiftUI

struct SignInFirstFactorView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject var signInViewModel: SignInView.Model
    
    @State private var otpCode = ""
    @State private var isSubmittingOTPCode = false
    
    private var userData: UserData {
        clerk.client.signIn.userData
    }
    
    private var firstFactor: SignInFactor? {
        clerk.client.signIn.supportedFirstFactors.first(where: { $0.strategy == VerificationStrategy.emailCode.stringValue })
    }
    
    private func prepareFirstFactor() async {
        do {
            try await clerk
                .client
                .signIn
                .prepareFirstFactor(.init(
                    emailAddressId: firstFactor?.emailAddressId,
                    strategy: .emailCode
                ))
        } catch {
            dump(error)
        }
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
                imageUrl: userData.imageUrl,
                label: firstFactor?.safeIdentifier ?? "",
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
                    isSubmittingOTPCode = newValue.count == 6
                }
                
                AsyncButton(options: [.disableButton], action: {
                    await prepareFirstFactor()
                }, label: {
                    Text("Didn't recieve a code? Resend")
                        .font(.subheadline)
                })
                .tint(Color(.clerkPurple))
            }
            
            AsyncButton(action: {
                signInViewModel.step = .create
            }, label: {
                Text("Use another method")
                    .font(.subheadline)
            })
            .tint(Color(.clerkPurple))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(30)
        .background(.background)
    }
}

struct SignInFirstFactorView_Previews: PreviewProvider {
    static var previews: some View {
        SignInFirstFactorView()
            .environmentObject(Clerk.mock)
    }
}
