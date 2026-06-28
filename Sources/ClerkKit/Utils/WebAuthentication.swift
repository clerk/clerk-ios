//
//  WebAuthentication.swift
//

import AuthenticationServices

@available(tvOS 16.0, watchOS 6.2, *)
@MainActor
final class WebAuthentication: NSObject {
  typealias SessionFactory = @MainActor (
    URL,
    String?,
    @escaping ASWebAuthenticationSession.CompletionHandler
  ) -> ASWebAuthenticationSession

  let url: URL
  let prefersEphemeralWebBrowserSession: Bool
  private let callbackURLSchemeOverride: String?
  private let sessionFactory: SessionFactory

  private struct ActiveSession {
    let identifier: Int
    let session: ASWebAuthenticationSession
    let continuation: CheckedContinuation<URL, any Error>
    /// Retains the presentation context provider while the system auth UI is active.
    let presentationContextProvider: WebAuthentication
  }

  private static var activeSession: ActiveSession?
  private static var nextSessionIdentifier = 0
  private static var suppressNextForegroundRefresh = false

  init(
    url: URL,
    prefersEphemeralWebBrowserSession: Bool = false,
    callbackURLScheme: String? = nil,
    sessionFactory: @escaping SessionFactory = WebAuthentication.makeSession
  ) {
    self.url = url
    self.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
    callbackURLSchemeOverride = callbackURLScheme
    self.sessionFactory = sessionFactory
  }

  private static func makeSession(
    url: URL,
    callbackURLScheme: String?,
    completionHandler: @escaping ASWebAuthenticationSession.CompletionHandler
  ) -> ASWebAuthenticationSession {
    ASWebAuthenticationSession(
      url: url,
      callbackURLScheme: callbackURLScheme,
      completionHandler: completionHandler
    )
  }

  private static func completeSession(
    identifier: Int? = nil,
    with url: URL?,
    error: Error?,
    suppressForegroundRefresh: Bool = false
  ) {
    guard identifier == nil || activeSession?.identifier == identifier else {
      return
    }

    #if os(macOS)
    if suppressForegroundRefresh {
      suppressNextForegroundRefresh = true
    }
    #endif

    defer {
      activeSession = nil
    }

    guard let continuation = activeSession?.continuation else {
      return
    }

    if let url {
      continuation.resume(returning: url)
    } else if let error {
      continuation.resume(throwing: error)
    } else {
      continuation.resume(throwing: ClerkClientError(message: "Missing callback URL"))
    }
  }

  private static func makeSessionIdentifier() -> Int {
    nextSessionIdentifier += 1
    return nextSessionIdentifier
  }

  private static func cancelSession(identifier: Int? = nil) {
    guard identifier == nil || activeSession?.identifier == identifier else {
      return
    }

    #if !os(tvOS)
    activeSession?.session.cancel()
    #endif

    completeSession(identifier: identifier, with: nil, error: CancellationError())
  }

  private func beginSession(identifier sessionIdentifier: Int, continuation: CheckedContinuation<URL, any Error>) {
    guard Self.activeSession == nil else {
      continuation.resume(throwing: ClerkClientError(message: "A web authentication session is already in progress."))
      return
    }

    guard !Task.isCancelled else {
      continuation.resume(throwing: CancellationError())
      return
    }

    let session = sessionFactory(
      url,
      callbackURLSchemeOverride ?? Clerk.shared.options.redirectConfig.callbackUrlScheme
    ) { @Sendable url, error in
      Task { @MainActor in
        WebAuthentication.completeSession(
          identifier: sessionIdentifier,
          with: url,
          error: error,
          suppressForegroundRefresh: true
        )
      }
    }

    #if !os(watchOS) && !os(tvOS)
    session.presentationContextProvider = self
    #endif

    #if !os(tvOS)
    session.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
    #endif

    Self.activeSession = ActiveSession(
      identifier: sessionIdentifier,
      session: session,
      continuation: continuation,
      presentationContextProvider: self
    )

    guard !Task.isCancelled else {
      Self.cancelSession(identifier: sessionIdentifier)
      return
    }

    guard session.start() else {
      Self.completeSession(
        identifier: sessionIdentifier,
        with: nil,
        error: ClerkClientError(message: "Unable to start web authentication session.")
      )
      return
    }
  }

  func start() async throws -> URL {
    let sessionIdentifier = Self.makeSessionIdentifier()

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        beginSession(identifier: sessionIdentifier, continuation: continuation)
      }
    } onCancel: {
      Task { @MainActor in
        WebAuthentication.cancelSession(identifier: sessionIdentifier)
      }
    }
  }

  static func finishWithDeeplinkUrl(url: URL) {
    #if targetEnvironment(macCatalyst)
    // mac catalyst web auth window doesn't close without
    // this when the callback is intercepted as a universal link
    activeSession?.session.cancel()
    #endif

    completeSession(with: url, error: nil, suppressForegroundRefresh: true)
  }

  static func cancelCurrentSession() {
    cancelSession()
  }

  static func consumePendingForegroundRefreshSuppression() -> Bool {
    defer { suppressNextForegroundRefresh = false }
    return suppressNextForegroundRefresh
  }
}

#if !os(watchOS) && !os(tvOS)
extension WebAuthentication: ASWebAuthenticationPresentationContextProviding {
  @MainActor
  func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
    PresentationAnchorProvider.current
  }
}

#endif
