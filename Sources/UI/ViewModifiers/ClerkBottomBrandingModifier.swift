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
                        .shadow(color: .primary.opacity(0.08), radius: 0.5, x: 0, y: 1)
                        .shadow(color: Color(red: 0.1, green: 0.11, blue: 0.13).opacity(0.06), radius: 1, x: 0, y: 1)
                        .shadow(color: Color(red: 0.1, green: 0.11, blue: 0.13).opacity(0.04), radius: 0, x: 0, y: 0)
                        .ignoresSafeArea()
                }
                    
            SecuredByClerkView()
                .padding(.vertical, 16)
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
