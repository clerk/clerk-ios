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
    @State private var clerk = Clerk.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
<<<<<<< HEAD
                    clerk.configure(publishableKey: "YOUR_PUBLISHABLE_KEY")
                    do {
                        try await clerk.load()
                    } catch {
                        dump(error)
                    }
=======
                    clerk.configure(publishableKey: "pk_test_YW11c2luZy1iYXJuYWNsZS0yNi5jbGVyay5hY2NvdW50cy5kZXYk")
                    try? await clerk.load()
>>>>>>> 958e51a3 (Replace Kingfisher with NukeUI for image handling in ClerkKit components, enhancing performance and consistency. Update Package.swift to remove Kingfisher dependency and add NukeUI where necessary. Adjust image loading logic across various views to utilize LazyImage for improved loading behavior.)
                }
                #if DEBUG
                .task { Atlantis.start() }
                #endif
        }
    }
}
