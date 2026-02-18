//
//  ClerkImagePrefetch.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import Nuke
import SwiftUI

extension Clerk {
  /// Prefetches environment images (OAuth logos and app brand logo) into the image cache.
  ///
  /// Call this method after Clerk is configured and the environment is loaded
  /// to ensure images are cached before they're displayed in the UI.
  /// OAuth provider logos are prefetched once.
  ///
  /// Example:
  /// ```swift
  /// // After environment is loaded
  /// Clerk.shared.prefetchImages()
  /// ```
  @MainActor
  public func prefetchImages(includeAppLogo: Bool = true) {
    guard let environment else { return }

    var urls = Set<URL>()

    // App brand logo
    if includeAppLogo,
      let logoUrl = URL(string: environment.displayConfig.logoImageUrl)
    {
      urls.insert(logoUrl)
    }

    // OAuth provider logos (all enabled providers)
    for provider in environment.allSocialProviders {
      if let logoUrl = provider.iconImageUrl {
        urls.insert(logoUrl)
      }
    }

    guard !urls.isEmpty else { return }

    let prefetcher = ImagePrefetcher()
    prefetcher.startPrefetching(with: Array(urls))
  }
}

// MARK: - View Modifier

extension View {
  /// Prefetches Clerk environment images (OAuth logos and app brand logo) when the view appears.
  ///
  /// This modifier automatically waits for the Clerk environment to load before prefetching.
  /// Images are cached by Nuke and will load instantly when displayed in Clerk UI components.
  /// OAuth provider logos are prefetched once.
  ///
  /// Example:
  /// ```swift
  /// @main
  /// struct MyApp: App {
  ///   var body: some Scene {
  ///     WindowGroup {
  ///       ContentView()
  ///         .prefetchClerkImages()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// - Returns: A view that prefetches Clerk images when it appears.
  public func prefetchClerkImages() -> some View {
    modifier(ClerkImagePrefetchModifier())
  }
}

private struct ClerkImagePrefetchModifier: ViewModifier {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkAppIcon) private var appIconOverride

  func body(content: Content) -> some View {
    content
      .onChange(of: clerk.environment, initial: true) {
        clerk.prefetchImages(includeAppLogo: appIconOverride == nil)
      }
  }
}

#endif
