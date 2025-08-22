//
//  ClerkRevCatApp.swift
//  ClerkRevCat
//
//  Created by Mike Pitre on 8/19/25.
//

import Clerk
import SwiftUI

@main
struct ClerkRevCatApp: App {
    @State private var clerk = Clerk.shared
    @State private var revenueCatManager = RevenueCatManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(revenueCatManager)
                .environment(clerk)
                .task {
                    clerk.configure(publishableKey: "YOUR_CLERK_PUBLISHABLE_KEY")
                    try? await clerk.load()
                }
                .onChange(of: clerk.user) { oldUser, newUser in
                    Task {
                        if let newUser = newUser {
                            // User signed in - login to RevenueCat
                            await revenueCatManager.loginUser(withClerkUserId: newUser.id)
                        } else {
                            // User signed out - logout from RevenueCat
                            await revenueCatManager.logoutUser()
                        }
                    }
                }
        }
    }
}
