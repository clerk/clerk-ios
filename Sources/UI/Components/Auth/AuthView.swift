//
//  SignInView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

public struct AuthView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    
    public var body: some View {
        Group {
            switch clerkUIState.presentedAuthStep {
            case .signInStart:
                SignInStartView()
            case .signInFirstFactor:
                SignInFactorOneView()
            case .signUpStart:
                SignUpStartView()
            case .signUpVerification:
                SignUpVerificationView()
            }
        }
        .frame(maxWidth: .infinity)
        .background(.background)
        .transition(.offset(y: 50).combined(with: .opacity))
        .animation(.bouncy, value: clerkUIState.presentedAuthStep)
        .overlay(alignment: .topTrailing) {
            Button(action: {
                clerkUIState.authIsPresented = false
            }, label: {
                Text("Cancel")
                    .font(.caption.weight(.medium))
            })
            .padding(30)
            .tint(.primary)
        }
        .onChange(of: clerkUIState.presentedAuthStep) { _ in
            KeyboardHelpers.dismissKeyboard()
        }
        .task {
            try? await clerk.environment.get()
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
