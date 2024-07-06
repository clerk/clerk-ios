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
                #if os(iOS)
                .clerkProvider()
                #endif
                .task {
                    Clerk.shared.configure(publishableKey: publishableKey, debugMode: true)
                    try? await Clerk.shared.load()
                }
        }
    }
}
