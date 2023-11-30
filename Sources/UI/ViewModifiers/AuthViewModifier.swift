//
//  SignInViewModifier.swift
//
//
//  Created by Mike Pitre on 10/12/23.
//

#if canImport(UIKit)

import Foundation
import SwiftUI
import Clerk

struct AuthViewModifier: ViewModifier {
    @Environment(\.clerkTheme) private var clerkTheme
    
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        Group {
            switch clerkTheme.authPresentationStyle {
            case .sheet: sheetStyle(content: content)
            case .fullScreenCover: fullScreenCoverStyle(content: content)
            }
        }
    }
    
    @ViewBuilder
    private func sheetStyle(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, content: {
                AuthView()
            })
    }
    
    @ViewBuilder
    private func fullScreenCoverStyle(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented, content: {
                AuthView()
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
}

#endif
