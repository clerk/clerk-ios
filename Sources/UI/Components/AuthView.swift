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
    @Namespace private var namespace
    
    public var body: some View {
        ZStack {
            switch clerkUIState.presentedAuthStep {
            case .signInCreate:
                SignInCreateView()
                    .matchedGeometryEffect(id: "view", in: namespace)
            case .signInFirstFactor:
                SignInFirstFactorView()
                    .matchedGeometryEffect(id: "view", in: namespace)
            case .signUpCreate:
                SignUpCreateView()
                    .matchedGeometryEffect(id: "view", in: namespace)
            case .signUpVerification:
                SignUpVerificationView()
                    .matchedGeometryEffect(id: "view", in: namespace)
            }
        }
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
}

#endif