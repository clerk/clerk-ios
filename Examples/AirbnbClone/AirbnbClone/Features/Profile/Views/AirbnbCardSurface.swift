//
//  AirbnbCardSurface.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import SwiftUI

struct AirbnbCardSurfaceModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  let cornerRadius: CGFloat

  func body(content: Content) -> some View {
    content
      .background(Color(uiColor: .systemBackground))
      .clipShape(.rect(cornerRadius: cornerRadius))
      .overlay {
        if colorScheme == .dark {
          RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
      }
      .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 10)
      .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
  }
}

extension View {
  func airbnbCardSurface(cornerRadius: CGFloat = 28) -> some View {
    modifier(AirbnbCardSurfaceModifier(cornerRadius: cornerRadius))
  }
}
