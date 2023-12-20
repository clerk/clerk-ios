//
//  ClerkBottomBrandingModifier.swift
//
//
//  Created by Mike Pitre on 12/20/23.
//

import SwiftUI
import Clerk

struct ClerkBottomBrandingModifier: ViewModifier {
    @Environment(\.clerkTheme) private var clerkTheme
    
    func body(content: Content) -> some View {
        VStack(spacing: -8) {
            content
                .background {
                    Color(.systemBackground)
                        .clipShape(UnevenRoundedRectangle(cornerRadii: .init(bottomLeading: 8, bottomTrailing: 8), style: .continuous))
                        .shadow(radius: 1)
                        .ignoresSafeArea()
                }
                    
            SecuredByClerkView()
                .padding(.vertical, 8)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .zIndex(-1)
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
