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

  private static var currentSession: ASWebAuthenticationSession?
  private static var currentSessionIdentifier: Int?
  private static var currentContinuation: CheckedContinuation<URL, any Error>?
  // Retains the presentation context provider while the system auth UI is active.
  private static var currentPresentationContextProvider: WebAuthentication?
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

  private static func clearSession() {
    currentSession = nil
    currentSessionIdentifier = nil
    currentPresentationContextProvider = nil
  }

  private static func completeSession(identifier: Int? = nil, with url: URL?, error: Error?) {
    guard identifier == nil || currentSessionIdentifier == identifier else {
      return
    }

    defer {
      currentContinuation = nil
      clearSession()
    }

    guard let continuation = currentContinuation else {
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

  func start() async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      guard Self.currentContinuation == nil else {
        continuation.resume(throwing: ClerkClientError(message: "A web authentication session is already in progress."))
        return
      }

      let sessionIdentifier = Self.makeSessionIdentifier()
      let session = sessionFactory(
        url,
        callbackURLSchemeOverride ?? Clerk.shared.options.redirectConfig.callbackUrlScheme
      ) { @Sendable url, error in
        Task { @MainActor in
          #if os(macOS)
          WebAuthentication.suppressNextForegroundRefresh = true
          #endif
          WebAuthentication.completeSession(identifier: sessionIdentifier, with: url, error: error)
        }
      }

      #if !os(watchOS) && !os(tvOS)
      session.presentationContextProvider = self
      #endif

      #if !os(tvOS)
      session.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
      #endif

      Self.currentSession = session
      Self.currentSessionIdentifier = sessionIdentifier
      Self.currentPresentationContextProvider = self
      Self.currentContinuation = continuation

      guard session.start() else {
        Self.completeSession(
          identifier: sessionIdentifier,
          with: nil,
          error: ClerkClientError(message: "Unable to start web authentication session.")
        )
        return
      }
    }
  }

  static func finishWithDeeplinkUrl(url: URL) {
    #if os(macOS)
    suppressNextForegroundRefresh = true
    #endif

    #if targetEnvironment(macCatalyst)
    // mac catalyst web auth window doesn't close without
    // this when the callback is intercepted as a universal link
    currentSession?.cancel()
    #endif

    completeSession(with: url, error: nil)
  }

  static func cancelCurrentSession() {
    #if !os(tvOS)
    currentSession?.cancel()
    #endif

    defer {
      currentContinuation = nil
      clearSession()
    }

    guard let continuation = currentContinuation else { return }
    continuation.resume(throwing: CancellationError())
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
