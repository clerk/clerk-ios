//
//  UserProfileViewModifier.swift
//
//
//  Created by Mike Pitre on 11/29/23.
//

#if canImport(SwiftUI)

import SwiftUI

struct UserProfileViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    @EnvironmentObject private var clerkUIState: ClerkUIState
    
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
                        .environmentObject(clerkUIState)
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
