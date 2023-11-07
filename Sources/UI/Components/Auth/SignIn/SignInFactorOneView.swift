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
        
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    var body: some View {
        Group {
            switch signIn.firstFactorStrategy {
            case .password:
                SignInFactorOnePasswordView()
            case .emailCode:
                SignInFactorOneEmailCodeView()
            case .phoneCode:
                SignInFactorOnePhoneCodeView()
            default:
                ProgressView()
                    .task {
                        switch signIn.status {
                        case .needsSecondFactor:
                            clerkUIState.presentedAuthStep = .signInFactorTwo
                        default:
                            clerkUIState.authIsPresented = false
                        }
                    }
            }
        }
        .transition(.offset(y: 50).combined(with: .opacity))
        .animation(.snappy, value: signIn.firstFactorStrategy)
    }
}

#Preview {
    SignInFactorOneView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
