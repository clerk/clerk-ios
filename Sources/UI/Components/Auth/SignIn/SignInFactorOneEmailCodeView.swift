//
//  SignInFactorOneEmailCodeView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

import SwiftUI
import Clerk

struct SignInFactorOneEmailCodeView: View {
    @EnvironmentObject private var clerk: Clerk
    
    @State private var otpCode: String = ""
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    var body: some View {
        ScrollView {
            VerificationCodeView(
                otpCode: $otpCode,
                title: "Check your email",
                subtitle: "to continue to \(clerk.environment.displayConfig.applicationName)",
                formTitle: "Verification code",
                formSubtitle: "Enter the verification code sent to your email address",
                safeIdentifier: signIn.firstFactor?.safeIdentifier
            )
        }
    }
}

#Preview {
    SignInFactorOneEmailCodeView()
        .environmentObject(Clerk.mock)
}
