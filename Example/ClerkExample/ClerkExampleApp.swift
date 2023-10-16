//
//  ClerkExampleApp.swift
//  ClerkExample
//
//  Created by Mike Pitre on 10/2/23.
//

#if canImport(UIKit)

import SwiftUI

@main
struct ClerkExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ExamplesListView()
                .clerkProvider(
                    publishableKey: "",
                    frontendAPIURL: ""
                )
        }
    }
}

#else

@main
struct ClerkExampleApp: App {
    var body: some Scene {
        WindowGroup {
            Text("MacOS not supported.")
        }
    }
}

#endif
