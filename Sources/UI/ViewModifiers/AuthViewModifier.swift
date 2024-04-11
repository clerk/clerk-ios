//
//  SignInViewModifier.swift
//
//
//  Created by Mike Pitre on 10/12/23.
//

#if os(iOS)

import Foundation
import SwiftUI

struct AuthViewModifier: ViewModifier {
    @Environment(\.clerkTheme) private var clerkTheme
    @EnvironmentObject private var clerkUIState: ClerkUIState
    
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, content: {
                AuthView()
                    .environmentObject(clerkUIState)
            })
    }
}

extension View {
    func authView(isPresented: Binding<Bool>) -> some View {
        modifier(AuthViewModifier(isPresented: isPresented))
    }
}

#Preview {
    Text("SignIn")
        .authView(isPresented: .constant(true))
        .environmentObject(ClerkUIState())
}

#endif
