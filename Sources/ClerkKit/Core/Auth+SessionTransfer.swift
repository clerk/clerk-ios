//
//  Auth+SessionTransfer.swift
//  Clerk
//

import Foundation

#if !os(tvOS) && !os(watchOS)

extension Auth {
  /// Creates a one-time URL that signs the active session's user in on a web page.
  ///
  /// Every call creates a new transfer. The URL works once, for about a minute, so create it right
  /// before you open it, and never log or store it. When the web page can't redeem it, the page loads
  /// `destination` with `__clerk_status=failed` and a `__clerk_error_code` query parameter.
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
}

#endif
