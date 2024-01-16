//
//  ClerkBottomBrandingModifier.swift
//
//
//  Created by Mike Pitre on 12/20/23.
//

import SwiftUI
import Clerk

struct ClerkBottomBrandingModifier: ViewModifier {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    
    func body(content: Content) -> some View {
        if clerk.environment.displayConfig.branded {
            VStack(spacing: -8) {
                content
                    .background {
                        Color(.systemBackground)
                            .raisedCardBottom()
                            .ignoresSafeArea()
                    }
                        
                SecuredByClerkView()
                    .padding(.vertical, 8)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .zIndex(-1)
            }
        } else {
            content
        }
    }
}

extension View {
    public func clerkBottomBranding() -> some View {
        modifier(ClerkBottomBrandingModifier())
    }
}

#Preview {
    AuthView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}
