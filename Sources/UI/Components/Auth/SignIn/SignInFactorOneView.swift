//
//  SignInFactorOneView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInFactorOneView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    
    @State private var otpCode = ""
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    private var titleString: String {
        switch signIn.strategy {
        case .emailCode:
            return "Check your email"
        case .phoneCode:
            return "Verify your phone"
        default:
            return ""
        }
    }
    
    private var instructionsString: String {
        switch signIn.strategy {
        case .emailCode:
            return "Enter the verification code sent to your email address"
        case .phoneCode:
            return "Enter the verification code sent to your phone number"
        default:
            return ""
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VerificationCodeView(
                    otpCode: $otpCode,
                    title: titleString,
                    subtitle: "to continue to \(clerk.environment.displayConfig.applicationName)",
                    formTitle: "Verification code",
                    formSubtitle: instructionsString,
                    safeIdentifier: signIn.firstFactor?.safeIdentifier,
                    profileImageUrl: signIn.userData?.imageUrl
                )
                .onIdentityPreviewTapped {
                    clerkUIState.presentedAuthStep = .signInStart
                }
                .onCodeEntry {
                    await attemptFirstFactor()
                }
                .onResend {
                    await prepareFirstFactor()
                }
                .onUseAlernateMethod {
                    clerkUIState.presentedAuthStep = .signInStart
                }
            }
        }
    }
    
    private func prepareFirstFactor() async {
        do {
            switch signIn.strategy {
            case .emailCode:
                try await signIn.prepareFirstFactor(.emailCode)
            case .phoneCode:
                try await signIn.prepareFirstFactor(.phoneCode)
            default:
                throw ClerkClientError(message: "Unable to prepare verification.")
            }
            
        } catch {
            dump(error)
        }
    }
    
    private func attemptFirstFactor() async {
        KeyboardHelpers.dismissKeyboard()
        
        do {
            switch signIn.strategy {
            case .emailCode:
                try await signIn.attemptFirstFactor(.emailCode(code: otpCode))
            case .phoneCode:
                try await signIn.attemptFirstFactor(.phoneCode(code: otpCode))
            default:
                throw ClerkClientError(message: "Unable to attempt verification.")
            }
            
            clerkUIState.authIsPresented = false
        } catch {
            dump(error)
        }
    }
}

#Preview {
    SignInFactorOneView()
        .environmentObject(Clerk.mock)
}

#endif
