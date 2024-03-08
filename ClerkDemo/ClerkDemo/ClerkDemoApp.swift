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
    
    init() {
        Clerk.shared.load(publishableKey: "")
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .clerkProvider()
        }
    }
}
