//
//  ProviderIconView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct ProviderIconView: View {
  @Environment(\.colorScheme) private var colorScheme

  let provider: OAuthProvider
  let image: Image
  var foregroundColor: Color?

  private var resolvedForegroundColor: Color {
    if let foregroundColor {
      return foregroundColor
    }

    return colorScheme == .dark ? .white : .black
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
