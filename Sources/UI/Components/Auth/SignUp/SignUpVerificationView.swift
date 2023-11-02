//
//  SignUpVerificationView.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import Factory

struct SignUpVerificationView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
        
    private var signUp: SignUp {
        clerk.client.signUp
    }
    
    var body: some View {
        Group {
            switch signUp.nextStrategyToVerify {
            case .phoneCode:
                SignUpPhoneCodeView()
            case .emailCode:
                SignUpEmailCodeView()
            default:
                ProgressView()
                    .task { clerkUIState.authIsPresented = false }
            }
        }
        .transition(.offset(y: 50).combined(with: .opacity))
        .animation(.bouncy, value: signUp.nextStrategyToVerify)
    }
}

#Preview {
    let _ = Container.shared.clerk.register { Clerk.mock }
    return SignUpVerificationView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
