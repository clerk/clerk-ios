//
//  ClerkProviderModifier.swift
//  
//
//  Created by Mike Pitre on 10/3/23.
//

import Foundation
import SwiftUI

/**
 This modifier configures your clerk shared instance, and injects it into the environment as an environmentObject.
 You can observe changes to the Clerk object via `EnvironmentObject var clerk: Clerk` from any descendant view.
 
 You should apply this modifier to the root view of your application. Most likely in your `App` file.
 */
struct ClerkProviderModifier: ViewModifier {
    
    init(publishableKey: String, frontendAPIURL: String) {
        Clerk.shared.configure(
            publishableKey: publishableKey,
            frontendAPIURL: frontendAPIURL
        )
    }
    
    func body(content: Content) -> some View {
        content
            .environmentObject(Clerk.shared)
            .task {
                do {
                    try await Clerk.shared.client.get()
                } catch {
                    try? await Clerk.shared.client.create()
                }
            }
            .task {
                try? await Clerk.shared.environment.get()
            }
    }
}

extension View {
    /**
     This modifier configures your clerk shared instance, and injects it into the environment as an environmentObject.
     You can observe changes to the Clerk object via `EnvironmentObject var clerk: Clerk` from any descendant view.
     
     You should apply this modifier to the root view of your application. Most likely in your `App` file.
     */
    public func clerkProvider(publishableKey: String, frontendAPIURL: String) -> some View {
        modifier(ClerkProviderModifier(
            publishableKey: publishableKey,
            frontendAPIURL: frontendAPIURL
        ))
    }
}
