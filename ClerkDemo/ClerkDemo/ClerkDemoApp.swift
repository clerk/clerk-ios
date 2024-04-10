//
//  ClerkDemoApp.swift
//  ClerkDemo
//
//  Created by Mike Pitre on 3/8/24.
//

import SwiftUI
import ClerkSDK

@main
struct ClerkDemoApp: App {
    @AppStorage("publishableKey") var publishableKey: String = ""
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .clerkProvider()
                .task {
                    Clerk.shared.configure(publishableKey: publishableKey)
                    try? await Clerk.shared.load()
                }
        }
    }
}
