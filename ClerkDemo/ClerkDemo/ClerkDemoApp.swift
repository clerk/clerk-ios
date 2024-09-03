//
//  ClerkDemoApp.swift
//  ClerkDemo
//
//  Created by Mike Pitre on 3/8/24.
//

import SwiftUI
import ClerkSDK
import Atlantis

@main
struct ClerkDemoApp: App {
    @AppStorage("publishableKey") var publishableKey: String = ""
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .task {
                    Clerk.shared.configure(publishableKey: publishableKey, debugMode: true)
                    try? await Clerk.shared.load()
                }
                .onOpenURL { url in
                    Task { await Clerk.handleUrl(url) }
                }
                #if os(iOS)
                .clerkProvider()
                #endif
                #if DEBUG
                .task { Atlantis.start() }
                #endif
        }
    }
}
