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
 This modifier configures your clerk shared instance, and injects it into the environment as an environmentObject.
 
 It also performs some Clerk specific setup.
 
 You should apply this modifier to the root view of your application. Most likely in your `App` file.
 */
struct ClerkProviderModifier: ViewModifier {
    @StateObject private var clerkUIState = ClerkUIState()
    
    let publishableKey: String
    
    func body(content: Content) -> some View {
        content
            .task { Clerk.shared.load(publishableKey: publishableKey) }
            .authView(isPresented: $clerkUIState.authIsPresented)
            .userProfileView(isPresented: $clerkUIState.userProfileIsPresented)
            // these must be the last modifiers
            .environmentObject(Clerk.shared)
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
