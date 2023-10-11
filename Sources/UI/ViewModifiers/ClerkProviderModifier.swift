//
//  ClerkProviderModifier.swift
//  
//
//  Created by Mike Pitre on 10/3/23.
//

#if !os(macOS)

import Foundation
import SwiftUI

/**
 This modifier configures your clerk shared instance, and injects it into the environment as an environmentObject.
 You can observe changes to the Clerk object via `EnvironmentObject var clerk: Clerk` from any descendant view.
 
 You should apply this modifier to the root view of your application. Most likely in your `App` file.
 */
struct ClerkProviderModifier: ViewModifier {
    
    @ObservedObject private var clerk = Clerk.shared
    
    init(publishableKey: String, frontendAPIURL: String) {
        clerk.configure(
            publishableKey: publishableKey,
            frontendAPIURL: frontendAPIURL
        )
    }
    
    func body(content: Content) -> some View {
        content
            .task {
                do {
                    try await clerk.client.get()
                } catch {
                    try? await clerk.client.create()
                }
            }
            .task {
                try? await clerk.environment.get()
            }
            .signInView(
                isPresented: $clerk.signInIsPresented,
                presentationStyle: .modal
            )
            .environmentObject(clerk) // this must be the last modifier
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

#endif
