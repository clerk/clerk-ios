//
//  HomeView.swift
//  ClerkDemo
//
//  Created by Mike Pitre on 3/8/24.
//

import SwiftUI
import ClerkSDK

struct HomeView: View {
    
    var body: some View {
        NavigationStack {
            List {
                Section("Instructions:") {
                    Text("Create an account on [Clerk.com](https://www.clerk.com).")
                    Text("Create an app.")
                    Text("Copy your publishable key from the dashboard under the \"API Keys\" section.")
                    Text("Paste your publishable key in the settings of this app and tap \"Save\".")
                    Text("Tap the user button to get started.")
                }
                .font(.subheadline)
            }
            .navigationTitle("Clerk Demo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    UserButton()
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(Clerk.shared)
}
