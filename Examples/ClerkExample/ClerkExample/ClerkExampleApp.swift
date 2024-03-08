//
//  ClerkExampleApp.swift
//  ClerkExample
//
//  Created by Mike Pitre on 10/2/23.
//

#if canImport(UIKit)

import SwiftUI
import ClerkSDK

@main
struct ClerkExampleApp: App {
    
    init() {
        Clerk.shared.load(publishableKey: "")
    }
    
    var body: some Scene {
        WindowGroup {
            ExampleTabView()
                .clerkProvider()
        }
    }
}

#else

@main
struct ClerkExampleApp: App {
    var body: some Scene {
        WindowGroup {
            Text("ClerkUI does not support MacOS yet.")
        }
    }
}

#endif
