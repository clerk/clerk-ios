//
//  ClerkExampleApp.swift
//  ClerkExample
//
//  Created by Mike Pitre on 10/2/23.
//

#if canImport(UIKit)

import SwiftUI
import ClerkUI

@main
struct ClerkExampleApp: App {    
    var body: some Scene {
        WindowGroup {
            ExamplesListView()
                .clerkProvider(publishableKey: "")
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
