//
//  AppLogoView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkJSCore
import ClerkKit
import NukeUI
import SwiftUI

struct AppLogoView: View {
  @SwiftUI.Environment(ClerkJSCore.Clerk.self) private var clerk
  @SwiftUI.Environment(\.clerkAppIcon) private var appIconOverride
  @SwiftUI.Environment(\.clerkAppIconMaxHeight) private var appIconMaxHeight
  @SwiftUI.Environment(\.clerkAppIconView) private var appIconViewOverride

  var body: some View {
    Group {
      if let appIconViewOverride {
        appIconViewOverride
      } else {
        Group {
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
        .frame(maxHeight: appIconMaxHeight)
        .padding(.bottom, 24)
      }
    }
  }
}

#Preview("Default logo") {
  AppLogoView()
    .padding()
    .clerkPreview()
}

#Preview("Override logo and size") {
  AppLogoView()
    .padding()
    .clerkAppIcon(Image(systemName: "app.badge"))
    .clerkAppIcon(maxHeight: 72)
    .clerkPreview()
}

#Preview("Custom logo view") {
  AppLogoView()
    .clerkAppIconView {
      Image(systemName: "app.badge")
        .resizable()
        .scaledToFill()
        .frame(width: 144, height: 72)
        .clipped()
        .padding(.bottom, 32)
        .accessibilityLabel("Custom app logo")
    }
    .padding()
    .clerkPreview()
}

#endif
