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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    clerk.configure(publishableKey: "YOUR_PUBLISHABLE_KEY")
                    try? await clerk.load()
                }
        }
    }
}
