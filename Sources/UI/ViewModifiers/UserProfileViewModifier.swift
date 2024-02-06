//
//  UserProfileViewModifier.swift
//
//
//  Created by Mike Pitre on 11/29/23.
//

#if canImport(UIKit)

import SwiftUI
import ClerkSDK

struct UserProfileViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    UserProfileView()
                        .presentationDragIndicator(.visible)
                        .navigationTitle("Account")
                        .toolbar(content: {
                            ToolbarItem(placement: .topBarTrailing) {
                                DismissButton()
                            }
                        })
                }
            }
    }
}

extension View {
    func userProfileView(isPresented: Binding<Bool>) -> some View {
        modifier(UserProfileViewModifier(isPresented: isPresented))
    }
}

#endif
