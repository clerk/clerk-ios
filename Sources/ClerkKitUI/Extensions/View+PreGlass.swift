//
//  View+PreGlass.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation
import SwiftUI

// MARK: - Solid Navbar

struct PreGlassSolidNavBarModifier: ViewModifier {
  @Environment(\.clerkTheme) private var theme

  func body(content: Content) -> some View {
    #if os(iOS)
    if #available(iOS 26.0, *) {
      content
    } else {
      content
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(theme.colors.background, for: .navigationBar)
    }
    #elseif os(macOS)
    content
    #endif
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
    #if os(iOS)
    if #available(iOS 26.0, *) {
      content
    } else {
      content
        .background(theme.colors.background)
        .presentationBackground(theme.colors.background)
    }
    #elseif os(macOS)
    content
      .background(theme.colors.background)
      .presentationBackground(theme.colors.background)
    #endif
  }
}

extension View {
  public func preGlassDetentSheetBackground() -> some View {
    modifier(PreGlassDetentSheetBackgroundModifier())
  }
}

#endif
