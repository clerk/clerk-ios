//
//  ClerkBottomBrandingModifier.swift
//
//
//  Created by Mike Pitre on 12/20/23.
//

import SwiftUI

struct ClerkBottomBrandingModifier: ViewModifier {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
        
    func body(content: Content) -> some View {
        if clerk.environment.displayConfig.branded {
            VStack(spacing: 0) {
                content
                        
                SecuredByClerkView()
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .top) {
                        Divider()
                    }
            }
        } else {
            content
        }
    }
}

extension View {
    func clerkBottomBranding() -> some View {
        modifier(ClerkBottomBrandingModifier())
    }
}

#Preview {
    AuthView()
        .environmentObject(Clerk.shared)
        .environmentObject(ClerkUIState())
}
