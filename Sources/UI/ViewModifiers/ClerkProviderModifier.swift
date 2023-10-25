//
//  ClerkProviderModifier.swift
//  
//
//  Created by Mike Pitre on 10/3/23.
//

#if canImport(UIKit)

import Foundation
import SwiftUI
import Clerk

/**
 This modifier configures your clerk shared instance, and injects it into the environment as an environmentObject.
 You can observe changes to the Clerk object via `EnvironmentObject var clerk: Clerk` from any descendant view.
 
 You should apply this modifier to the root view of your application. Most likely in your `App` file.
 */
struct ClerkProviderModifier: ViewModifier {
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.scenePhase) private var scenePhase
    
    @ObservedObject private var clerk = Clerk.shared
    @StateObject private var clerkUIState = ClerkUIState()
    
    init(publishableKey: String) {
        clerk.configure(publishableKey: publishableKey)
    }
    
    func body(content: Content) -> some View {
        content
            .authView(isPresented: $clerkUIState.authIsPresented)
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    Task.detached {
                        try? await clerk.environment.get()
                    }
                    Task.detached {
                        try? await clerk.client.get()
                        if await clerk.client.isPlaceholder {
                            try? await clerk.client.create()
                        }
                    }
                }
            }
            // these must be the last modifiers
            .environmentObject(clerk)
            .environmentObject(clerkUIState)
    }
}

extension View {
    /**
     This modifier configures your clerk shared instance, and injects it into the environment as an environmentObject.
     You can observe changes to the Clerk object via `EnvironmentObject var clerk: Clerk` from any descendant view.
     
     You should apply this modifier to the root view of your application. Most likely in your `App` file.
     */
    public func clerkProvider(publishableKey: String) -> some View {
        modifier(ClerkProviderModifier(publishableKey: publishableKey))
    }
}

#endif
