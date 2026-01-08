//
//  ClerkImagePrefetcher.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import Nuke

/// Prefetches images used by ClerkKitUI components.
@MainActor
public enum ClerkImagePrefetcher {
  private static let prefetcher = ImagePrefetcher()

  /// Prefetch all images used by ClerkKitUI (OAuth icons, app logo).
  /// Call this after Clerk environment is loaded.
  public static func prefetchImages() {
    guard let environment = Clerk.shared.environment else { return }

    var urls: [URL] = []

    // OAuth icons (light + dark variants)
    for (_, config) in environment.userSettings.social where config.enabled {
      if let logoUrl = config.logoUrl, !logoUrl.isEmpty {
        if let url = URL(string: logoUrl) { urls.append(url) }
        let darkUrl = logoUrl.replacingOccurrences(of: ".png", with: "-dark.png")
        if let url = URL(string: darkUrl) { urls.append(url) }
      }
    }

    // App logo
    if let logoUrl = environment.displayConfig.logoImageUrl,
       !logoUrl.isEmpty,
       let url = URL(string: logoUrl)
    {
      urls.append(url)
    }

    prefetcher.startPrefetching(with: urls)
  }
}

#endif
