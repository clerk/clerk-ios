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
                #if os(iOS)
                Section("Instructions:") {
                    Text("Create an account on [Clerk.com](https://www.clerk.com).")
                    Text("Create an app.")
                    Text("Copy your publishable key from the dashboard under the \"API Keys\" section.")
                    Text("Paste your publishable key in the settings of this app and tap \"Save\".")
                    Text("Tap the user button to get started.")
                }
                .font(.subheadline)
                #else
                Text("Clerk UI components are only supported on iOS (iPhone, iPad, Mac Catalyst), but you can still use the Clerk SDK to interact with the Clerk API on other platforms.")
                #endif
            }
            .navigationTitle("Clerk Demo")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    #if os(iOS)
                    UserButton()
                    #endif
                }
            }
        }
        .overlay {
            if clerk.loadingState == .notLoaded {
                VStack {
                    Spacer()
                    #if os(iOS)
                    OrgLogoView()
                        .frame(width: 100, height: 100)
                        .padding()
                    #endif
                    Spacer()
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background()
                .transition(.opacity.animation(.default))
            }
        }
        #if os(iOS)
        .demoSettings()
        #endif
    }
}

#Preview {
    HomeView()
}
