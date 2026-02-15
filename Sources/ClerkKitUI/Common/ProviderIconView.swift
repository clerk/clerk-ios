//
//  ProviderIconView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct ProviderIconView: View {
  let provider: OAuthProvider
  let image: Image
  let foregroundColor: Color

  @ViewBuilder
  var body: some View {
    if provider.supportsTintedIconMask {
      image
        .resizable()
        .renderingMode(.template)
        .scaledToFit()
        .foregroundStyle(foregroundColor)
    } else {
      image
        .resizable()
        .scaledToFit()
    }
  }
}

#endif
