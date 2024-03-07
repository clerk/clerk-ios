//
//  ExamplesProfileTabView.swift
//  ClerkExample
//
//  Created by Mike Pitre on 3/7/24.
//

import SwiftUI
import ClerkSDK

struct ExamplesProfileTabView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    
    var body: some View {
        NavigationStack {
            Group {
                if clerk.user == nil {
                    Button(action: {
                        clerkUIState.presentedAuthStep = .signInStart
                    }, label: {
                        Text("Sign In")
                    })
                } else {
                    UserProfileView()
                }
            }
            .navigationTitle("Account")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    UserButton()
                }
            }
        }
    }
}

#Preview {
    ExamplesProfileTabView()
}
