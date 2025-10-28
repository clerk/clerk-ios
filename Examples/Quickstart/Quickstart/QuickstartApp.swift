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
                    clerk.configure(publishableKey: "YOUR_PUBLISHABLE_KEY")
                    try? await clerk.load()
                }
                #if DEBUG
                .task { Atlantis.start() }
                #endif
        }
    }
}
