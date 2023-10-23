//
//  SignUpViewModifier.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI

struct SignUpViewModifier: ViewModifier {
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
                ScrollView {
                    SignUpView()
                        .presentationDragIndicator(.visible)
                        .interactiveDismissDisabled()
                }
            })
    }
    
    @ViewBuilder
    private func fullScreenCoverStyle(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented, content: {
                ScrollView {
                    SignUpView()
                        .presentationDragIndicator(.visible)
                        .interactiveDismissDisabled()
                }
            })
    }
}

extension View {
    func signUpView(
        isPresented: Binding<Bool>
    ) -> some View {
        modifier(SignUpViewModifier(
            isPresented: isPresented
        ))
    }
}


#Preview {
    Text("SignUp")
        .signUpView(isPresented: .constant(true))
}

#endif
