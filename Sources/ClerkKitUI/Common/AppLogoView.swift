//
//  AppLogoView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import NukeUI
import SwiftUI

struct AppLogoView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkAppIcon) private var appIconOverride

  var body: some View {
    if let appIconOverride {
      appIconOverride
        .resizable()
        .scaledToFit()
    } else {
      LazyImage(url: URL(string: clerk.environment?.displayConfig.logoImageUrl ?? "")) { state in
        if let image = state.image {
          image
            .resizable()
            .scaledToFit()
        } else if EnvironmentDetection.isRunningInPreviews {
          Image(systemName: "circle.square.fill")
            .resizable()
            .scaledToFit()
        }
      }
    }
  }
}

#Preview("Default logo") {
  AppLogoView()
    .padding()
    .clerkPreview()
}

#Preview("Override logo") {
  AppLogoView()
    .padding()
    .clerkAppIcon(Image(systemName: "app.badge"))
    .clerkPreview()
}

#endif
