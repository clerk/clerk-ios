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
                Section {
                    Text("1. Set your publishable key in the settings.")
                    Text("2. Tap the user button to get started.")
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
