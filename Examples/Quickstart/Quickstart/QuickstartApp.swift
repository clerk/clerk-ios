//
//  QuickstartApp.swift
//  Quickstart
//
//  Created by Mike Pitre on 7/30/25.
//

import Clerk
import SwiftUI

@main
struct QuickstartApp: App {
    @State private var clerk = Clerk.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    clerk.configure(publishableKey: "pk_test_YW11c2luZy1iYXJuYWNsZS0yNi5jbGVyay5hY2NvdW50cy5kZXYk")
                    try? await clerk.load()
                }
        }
    }
}
