//
//  UserProfileViewModifier.swift
//
//
//  Created by Mike Pitre on 11/29/23.
//

#if os(iOS)

import SwiftUI

struct UserProfileViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(ClerkUIState.self) private var clerkUIState
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    UserProfileView()
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
