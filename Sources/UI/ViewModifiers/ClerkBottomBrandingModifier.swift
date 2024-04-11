//
//  ClerkBottomBrandingModifier.swift
//
//
//  Created by Mike Pitre on 12/20/23.
//

#if os(iOS)

import SwiftUI

struct ClerkBottomBrandingModifier: ViewModifier {
    @ObservedObject private var clerk = Clerk.shared
    @Environment(\.clerkTheme) private var clerkTheme
        
    func body(content: Content) -> some View {
        if clerk.environment?.displayConfig.branded == true {
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
        .environmentObject(ClerkUIState())
}

#endif
