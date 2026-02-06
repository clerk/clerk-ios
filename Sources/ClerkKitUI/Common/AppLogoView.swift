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

  var body: some View {
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

#Preview {
  AppLogoView()
    .padding()
    .clerkPreview()
}

#endif
