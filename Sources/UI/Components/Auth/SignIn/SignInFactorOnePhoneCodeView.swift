//
//  SignInFactorOnePhoneCodeView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

import SwiftUI
import Clerk

struct SignInFactorOnePhoneCodeView: View {
    @EnvironmentObject private var clerk: Clerk
    
    @State private var otpCode: String = ""
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    var body: some View {
        ScrollView {
            VerificationCodeView(
                otpCode: $otpCode,
                title: "Check your phone",
                subtitle: "to continue to \(clerk.environment.displayConfig.applicationName)",
                formTitle: "Verification code",
                formSubtitle: "Enter the verification code sent to your phone number",
                safeIdentifier: signIn.firstFactor?.safeIdentifier
            )
        }
    }
}

#Preview {
    SignInFactorOnePhoneCodeView()
        .environmentObject(Clerk.mock)
}
