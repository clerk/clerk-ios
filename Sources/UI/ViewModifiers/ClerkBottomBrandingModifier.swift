//
//  ClerkBottomBrandingModifier.swift
//
//
//  Created by Mike Pitre on 12/20/23.
//

import SwiftUI
import ClerkSDK

struct ClerkBottomBrandingModifier: ViewModifier {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    
    var withRaisedCardContent: Bool = true
    
    func body(content: Content) -> some View {
        if clerk.environment.displayConfig.branded {
            VStack(spacing: -8) {
                content
                    .background {
                        if withRaisedCardContent {
                            Color(.systemBackground)
                                .raisedCardBottom()
                                .ignoresSafeArea()
                        } else {
                            Color(.systemBackground)
                                .ignoresSafeArea()
                        }
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
    public func clerkBottomBranding(withRaisedCardContent: Bool = true) -> some View {
        modifier(ClerkBottomBrandingModifier(withRaisedCardContent: withRaisedCardContent))
    }
}

#Preview {
    AuthView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}
