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
    
    init() {
        Clerk.shared.configure(publishableKey: publishableKey)
    }
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .clerkProvider()
                .task {
                    try? await Clerk.shared.load()
                }
        }
    }
}
