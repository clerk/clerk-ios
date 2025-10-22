//
//  View+PreGlass.swift
//  Clerk
//
//  Created by Mike Pitre on 6/11/25.
//

#if os(iOS)

import Foundation
import SwiftUI

// MARK: - Solid Navbar

struct PreGlassSolidNavBarModifier: ViewModifier {
    @Environment(\.clerkTheme) private var theme

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(theme.colors.background, for: .navigationBar)
        }
    }

}

extension View {
    public func preGlassSolidNavBar() -> some View {
        modifier(PreGlassSolidNavBarModifier())
    }
}

// MARK: - Detent Sheet Background

struct PreGlassDetentSheetBackgroundModifier: ViewModifier {
    @Environment(\.clerkTheme) private var theme

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content
                .background(theme.colors.background)
                .presentationBackground(theme.colors.background)
        }
    }

}

extension View {
    public func preGlassDetentSheetBackground() -> some View {
        modifier(PreGlassDetentSheetBackgroundModifier())
    }
}

#endif
