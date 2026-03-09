//
//  OAuthProviderBadgeView.swift
//  Clerk
//

import ClerkKit
import SwiftUI

struct OAuthProviderBadgeView: View {
  @Environment(\.clerkTheme) private var theme

  let provider: OAuthProvider

  var body: some View {
    AsyncImage(url: provider.iconImageUrl) { phase in
      switch phase {
      case .success(let image):
        image
          .resizable()
          .scaledToFit()
      default:
        Image(systemName: "person.crop.circle.badge.plus")
          .resizable()
          .scaledToFit()
          .padding(4)
          .foregroundStyle(theme.colors.mutedForeground)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
