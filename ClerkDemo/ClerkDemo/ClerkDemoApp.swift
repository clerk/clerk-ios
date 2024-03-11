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
        Clerk.shared.load(publishableKey: publishableKey)
    }
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .demoSettings() // only needed for the demo project
                .clerkProvider()
        }
    }
}
