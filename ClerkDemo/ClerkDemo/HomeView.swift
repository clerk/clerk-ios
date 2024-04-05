//
//  HomeView.swift
//  ClerkDemo
//
//  Created by Mike Pitre on 3/8/24.
//

import SwiftUI
import ClerkSDK

struct HomeView: View {    
    @ObservedObject private var clerk = Clerk.shared
    
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
        .overlay {
            if clerk.loadingState == .notLoaded {
                VStack {
                    Spacer()
                    OrgLogoView()
                        .frame(width: 100, height: 100)
                        .padding()
                    Spacer()
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background()
                .transition(.opacity.animation(.default))
            }
        }
        .demoSettings()
    }
}

#Preview {
    HomeView()
}
