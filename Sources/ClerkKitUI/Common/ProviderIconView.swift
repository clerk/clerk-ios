//
//  ProviderIconView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct ProviderIconView: View {
  @Environment(\.clerkTheme) private var theme

  let provider: OAuthProvider
  let image: Image
  var foregroundColor: Color?

  private var resolvedForegroundColor: Color {
    if let foregroundColor {
      return foregroundColor
    }

    return theme.colors.secondaryButtonForeground
  }

  var body: some View {
    if provider.supportsTintedIconMask {
      image
        .resizable()
        .renderingMode(.template)
        .scaledToFit()
        .foregroundStyle(resolvedForegroundColor)
    } else {
      image
        .resizable()
        .scaledToFit()
    }
  }
}

#endif
