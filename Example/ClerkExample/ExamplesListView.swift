//
//  ExamplesListView.swift
//  ClerkExample
//
//  Created by Mike Pitre on 10/6/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import ClerkUI

struct ExamplesListView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
        
    var body: some View {
        NavigationStack {
            List {
                Section("Components") {
                    Button {
                        clerkUIState.presentedAuthStep = .signInStart
                    } label: {
                        Text("Sign In")
                    }
                    
                    Button {
                        clerkUIState.presentedAuthStep = .signUpStart
                    } label: {
                        Text("Sign Up")
                    }
                }
            }
            .navigationTitle("Clerk Examples")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    UserButton()
                        .tint(.primary)
                }
            }
        }
    }
}

#Preview {
    ExamplesListView()
        .environmentObject(Clerk.mock)
}

#endif


