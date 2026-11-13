//
//  Auth+SessionTransfer.swift
//  Clerk
//

import Foundation

#if !os(tvOS) && !os(watchOS)

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WebKit)
import WebKit
#endif

typealias SessionTransferURLOpener = @MainActor (URL) async -> Bool

extension Auth {
  /// Creates a one-time URL that signs the active session's user in on a web page.
  ///
  /// Use it only to present the URL yourself. ``openInBrowser(destination:)`` and
  /// ``loadInWebView(_:destination:)`` create the URL and open it for you.
  ///
  /// Every call creates a new transfer. The URL works once, for about a minute, so create it right
  /// before you open it, and never log or store it. When the web page can't redeem it, the page loads
  /// `destination` with `__clerk_status=session_transfer_failed` and a `__clerk_error_code` query parameter.
  ///
  /// ```swift
  /// let transfer = try await clerk.auth.prepareSessionTransfer(
  ///   destination: URL(string: "https://app.example.com/settings")!,
  ///   presentation: .webView
  /// )
  /// webView.load(URLRequest(url: transfer.url))
  /// ```
  ///
  /// - Parameters:
  ///   - destination: An absolute `http` or `https` URL on one of your instance's domains. Production
  ///     instances accept only `https`.
  ///   - presentation: Where you will open the URL.
  /// - Returns: The URL and when it expires.
  /// - Throws: A ``ClerkClientError`` when there is no active session or `destination` is not an
  ///   `http` or `https` URL, before any network request. A ``ClerkAPIError`` when Clerk refuses to
  ///   create the transfer, such as `feature_not_enabled`.
  public func prepareSessionTransfer(
    destination: URL,
    presentation: SessionTransferPresentation
  ) async throws -> SessionTransfer {
    let params = try SessionTransferCreateParams(destination: destination, presentation: presentation)
    guard let session = Clerk.shared.activeSession else {
      throw ClerkClientError(message: "Session transfer requires an active session.", localizationBundle: .module)
    }
    return try await transport.send(SessionTransferAPI.create(sessionId: session.id, params: params))
      .value.response.sessionTransfer()
  }

  #if canImport(UIKit)
  /// Opens a web page in the user's default browser with the active session's user signed in.
  ///
  /// Returns once the system hands the URL to the browser. A refused sign-in still lands on
  /// `destination`, with `__clerk_status=session_transfer_failed` and a `__clerk_error_code` query
  /// parameter.
  ///
  /// ```swift
  /// try await clerk.auth.openInBrowser(destination: URL(string: "https://app.example.com/settings")!)
  /// ```
  ///
  /// - Parameter destination: An absolute `http` or `https` URL on one of your instance's domains.
  ///   Production instances accept only `https`.
  /// - Throws: The errors ``prepareSessionTransfer(destination:presentation:)`` throws, and a
  ///   ``ClerkClientError`` when no app can open the URL.
  public func openInBrowser(destination: URL) async throws {
    try await openInBrowser(destination: destination) { url in
      // SFSafariViewController keeps its own cookies, so a session redeemed there never reaches the
      // user's browser.
      await UIApplication.shared.open(url)
    }
  }
  #endif

  func openInBrowser(destination: URL, open: SessionTransferURLOpener) async throws {
    let transfer = try await prepareSessionTransfer(destination: destination, presentation: .browser)
    try Task.checkCancellation()
    guard await open(transfer.url) else {
      throw ClerkClientError(message: "No browser could open the sign-in link.", localizationBundle: .module)
    }
  }

  #if canImport(WebKit)
  /// Loads a web page in your web view with the active session's user signed in.
  ///
  /// The web view loads a Clerk page that signs the user in and then redirects to `destination`.
  /// Returns once that load starts, so watch the web view's navigation to tell when `destination`
  /// has loaded.
  ///
  /// A refused sign-in still lands on `destination`, with `__clerk_status=session_transfer_failed`
  /// and a `__clerk_error_code` query parameter, so check for them in your `WKNavigationDelegate`.
  ///
  /// The web view keeps its web session in its `WKWebsiteDataStore`. Clear that data store when the
  /// native user signs out or switches accounts, or the page can show the previous user.
  ///
  /// ```swift
  /// try await clerk.auth.loadInWebView(webView, destination: URL(string: "https://app.example.com/settings")!)
  /// ```
  ///
  /// - Parameters:
  ///   - webView: The web view to load the page in.
  ///   - destination: An absolute `http` or `https` URL on one of your instance's domains.
  ///     Production instances accept only `https`.
  /// - Throws: The errors ``prepareSessionTransfer(destination:presentation:)`` throws.
  public func loadInWebView(_ webView: WKWebView, destination: URL) async throws {
    let transfer = try await prepareSessionTransfer(destination: destination, presentation: .webView)
    try Task.checkCancellation()
    webView.load(URLRequest(url: transfer.url))
  }
  #endif
}

#endif
