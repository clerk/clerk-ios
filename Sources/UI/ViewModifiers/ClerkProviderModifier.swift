//
//  ClerkProviderModifier.swift
//  
//
//  Created by Mike Pitre on 10/3/23.
//

#if canImport(UIKit)

import Foundation
import SwiftUI

/**
 This modifier injects the clerk instance and clerkUIState into the environment.
  
 You should apply this modifier to the root view of your application. Most likely in your `App` file.
 */
struct ClerkProviderModifier: ViewModifier {
    @StateObject private var clerkUIState = ClerkUIState()
        
    func body(content: Content) -> some View {
        content
            .authView(isPresented: $clerkUIState.authIsPresented)
            .userProfileView(isPresented: $clerkUIState.userProfileIsPresented)
            // these must be the last modifiers
            .environmentObject(Clerk.shared)
            .environmentObject(clerkUIState)
    }
}

extension View {
    /**
     This modifier injects the clerk instance and clerkUIState into the environment.
     
     You can observe changes to this objects via `EnvironmentObject` from any descendant view.
     
     You should apply this modifier to the root view of your application. Most likely in your `App` file.
     */
    public func clerkProvider() -> some View {
        modifier(ClerkProviderModifier())
    }
}

#endif
