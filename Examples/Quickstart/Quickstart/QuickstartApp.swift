//
//  QuickstartApp.swift
//  Quickstart
//
//  Created by Mike Pitre on 7/30/25.
//

#if DEBUG
import Atlantis
#endif

import Clerk
import SwiftUI

@main
struct QuickstartApp: App {
    
    init() {
        Clerk.configure(publishableKey: "pk_test_YW11c2luZy1iYXJuYWNsZS0yNi5jbGVyay5hY2NvdW50cy5kZXYk")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    try? await Clerk.shared.load()
                }
                #if DEBUG
                .task { Atlantis.start() }
                #endif
        }
    }
}
