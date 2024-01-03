//
//  UserProfileViewModifier.swift
//
//
//  Created by Mike Pitre on 11/29/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct UserProfileViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                UserProfileView()
                    .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func userProfileView(isPresented: Binding<Bool>) -> some View {
        modifier(UserProfileViewModifier(isPresented: isPresented))
    }
}

#endif
