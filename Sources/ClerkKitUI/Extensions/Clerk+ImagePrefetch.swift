//
//  Clerk+ImagePrefetch.swift
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
  /// Both light and dark mode variants of OAuth provider logos are prefetched.
  ///
  /// Example:
  /// ```swift
  /// // After environment is loaded
  /// Clerk.shared.prefetchImages()
  /// ```
  @MainActor
  public func prefetchImages() {
    guard let environment else { return }

    var urls: [URL] = []

    // App brand logo
    if let logoUrl = URL(string: environment.displayConfig.logoImageUrl) {
      urls.append(logoUrl)
    }

    // OAuth provider logos (all enabled providers, light and dark variants)
    for provider in environment.allSocialProviders {
      if let lightUrl = provider.iconImageUrl(darkMode: false) {
        urls.append(lightUrl)
      }

      if let darkUrl = provider.iconImageUrl(darkMode: true) {
        urls.append(darkUrl)
      }
    }

    guard !urls.isEmpty else { return }

    let prefetcher = ImagePrefetcher()
    prefetcher.startPrefetching(with: urls)
  }
}

// MARK: - View Modifier

extension View {
  /// Prefetches Clerk environment images (OAuth logos and app brand logo) when the view appears.
  ///
  /// This modifier automatically waits for the Clerk environment to load before prefetching.
  /// Images are cached by Nuke and will load instantly when displayed in Clerk UI components.
  /// Both light and dark mode variants of OAuth provider logos are prefetched.
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

  func body(content: Content) -> some View {
    content
      .onChange(of: clerk.environment, initial: true) {
        clerk.prefetchImages()
      }
  }
}

#endif
