//
//  ClerkProviderModifier.swift
//  
//
//  Created by Mike Pitre on 10/3/23.
//

#if os(iOS)

import Foundation
import SwiftUI

/**
 This modifier injects the clerkUIState into the environment and attaches the needed UI modifiers.
  
 You should apply this modifier to the root view of your application. Most likely in your `App` file.
 */
struct ClerkProviderModifier: ViewModifier {
    @State private var clerkUIState = ClerkUIState()
    @State private var clerkTheme = ClerkTheme.clerkDefault
    
    func body(content: Content) -> some View {
        @Bindable var clerkUIState = clerkUIState
        
        content
            .authView(isPresented: $clerkUIState.authIsPresented)
            .userProfileView(isPresented: $clerkUIState.userProfileIsPresented)
            .environment(Clerk.shared)
            .environment(clerkUIState)
            .environment(clerkTheme)
    }
}

extension View {
    /**
     This modifier injects the clerkUIState into the environment.
          
     You should apply this modifier to the root view of your application. Most likely in your `App` file.
     */
    public func clerkProvider() -> some View {
        modifier(ClerkProviderModifier())
    }
}

#endif
