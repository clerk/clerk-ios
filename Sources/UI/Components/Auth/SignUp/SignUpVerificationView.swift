//
//  SignUpVerificationView.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Factory

struct SignUpVerificationView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @State private var errorWrapper: ErrorWrapper?
        
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { clerkUIState.setAuthStepToCurrentStatus(for: signUp) }
            }
        }
        .transition(.offset(y: 50).combined(with: .opacity))
        .animation(.snappy, value: signUp.nextStrategyToVerify)
        .onChange(of: signUp.nextStrategyToVerify) { _ in
            KeyboardHelpers.dismissKeyboard()
            FeedbackGenerator.success()
        }
    }
}

#Preview {
    return SignUpVerificationView()
        .environmentObject(ClerkUIState())
}

#endif
