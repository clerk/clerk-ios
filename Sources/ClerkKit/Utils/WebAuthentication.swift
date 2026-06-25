//
//  WebAuthentication.swift
//

import AuthenticationServices

actor WebAuthContinuationManager {
  private var continuation: CheckedContinuation<URL, any Error>?

  func setContinuation(_ continuation: CheckedContinuation<URL, any Error>) {
    self.continuation = continuation
  }

  func completeSession(with url: URL?, error: Error?) {
    defer {
      continuation = nil
    }

    guard let continuation else {
      ClerkLogger.warning("Continuation already completed. Ignoring.")
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

  func cancelSessionIfNeeded() {
    guard let continuation else { return }
    self.continuation = nil
    continuation.resume(throwing: CancellationError())
  }
}

actor WebAuthLifecycleRefreshManager {
  private var suppressNextForegroundRefresh = false

  func markPendingForegroundRefreshSuppression() {
    suppressNextForegroundRefresh = true
  }

  func consumePendingForegroundRefreshSuppression() -> Bool {
    defer { suppressNextForegroundRefresh = false }
    return suppressNextForegroundRefresh
  }
}

@available(tvOS 16.0, watchOS 6.2, *)
@MainActor
final class WebAuthentication: NSObject {
  static let continuationManager = WebAuthContinuationManager()
  private static let lifecycleRefreshManager = WebAuthLifecycleRefreshManager()

  let url: URL
  let prefersEphemeralWebBrowserSession: Bool

  static var currentSession: ASWebAuthenticationSession?
  static var currentAuthInstance: WebAuthentication?
  static var fallbackAnchor: AnyObject?

  /// Whether a web authentication session is currently active.
  /// Internal for @testable test access.
  static func hasActiveSession() -> Bool {
    currentSession != nil || currentAuthInstance != nil
  }

  private static func clearSession() {
    currentSession = nil
    currentAuthInstance = nil
    fallbackAnchor = nil
  }

  init(url: URL, prefersEphemeralWebBrowserSession: Bool = false) {
    self.url = url
    self.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
  }

  func start() async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      Task {
        let session = ASWebAuthenticationSession(
          url: url,
          callbackURLScheme: Clerk.shared.options.redirectConfig.callbackUrlScheme,
          completionHandler: { @Sendable url, error in
            Task {
              #if os(macOS)
              await WebAuthentication.lifecycleRefreshManager.markPendingForegroundRefreshSuppression()
              #endif
              await MainActor.run { WebAuthentication.clearSession() }
              await WebAuthentication.continuationManager.completeSession(with: url, error: error)
            }
          }
        )

        #if !os(watchOS) && !os(tvOS)
        session.presentationContextProvider = self
        #endif

        #if !os(tvOS)
        session.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
        #endif

        Self.currentSession = session
        Self.currentAuthInstance = self

        await WebAuthentication.continuationManager.setContinuation(continuation)

        await MainActor.run {
          let didStart = session.start()

          if !didStart {
            Self.clearSession()
            let startError = NSError(
              domain: "ClerkAuthError",
              code: -1,
              userInfo: [NSLocalizedDescriptionKey: "ASWebAuthenticationSession failed to start. Window context may be invalid."]
            )
            Task {
              await WebAuthentication.continuationManager.completeSession(with: nil, error: startError)
            }
          }
        }
      }
    }
  }

  static func finishWithDeeplinkUrl(url: URL) {
    Task {
      #if os(macOS)
      await lifecycleRefreshManager.markPendingForegroundRefreshSuppression()
      #endif

      #if targetEnvironment(macCatalyst)
      await MainActor.run { currentSession?.cancel() }
      #endif

      await MainActor.run { clearSession() }
      await continuationManager.completeSession(with: url, error: nil)
    }
  }

  static func cancelCurrentSession() async {
    #if !os(tvOS)
    currentSession?.cancel()
    #endif

    clearSession()

    await continuationManager.cancelSessionIfNeeded()
  }

  static func consumePendingForegroundRefreshSuppression() async -> Bool {
    await lifecycleRefreshManager.consumePendingForegroundRefreshSuppression()
  }
}

#if !os(watchOS) && !os(tvOS)
extension WebAuthentication: ASWebAuthenticationPresentationContextProviding {
  @MainActor
  func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
    #if os(iOS)
    let foregroundWindows = UIApplication.shared.connectedScenes
      .filter { $0.activationState == .foregroundActive }
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)

    if let window = foregroundWindows.first(where: \.isKeyWindow) ?? foregroundWindows.first {
      return window
    }
    let fallbackScene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first
    let fallbackWindow = fallbackScene.map { UIWindow(windowScene: $0) }
      ?? UIWindow(frame: UIScreen.main.bounds)
    fallbackWindow.isHidden = false
    Self.fallbackAnchor = fallbackWindow
    return fallbackWindow

    #elseif os(macOS)
    if let keyWindow = NSApp.keyWindow { return keyWindow }
    if let mainWindow = NSApp.mainWindow { return mainWindow }
    if let visibleWindow = NSApp.windows.first(where: { $0.isVisible && $0.className != "NSStatusBarWindow" }) { return visibleWindow }

    let tempWindow = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    tempWindow.makeKeyAndOrderFront(nil)
    Self.fallbackAnchor = tempWindow
    return tempWindow

    #else
    return ASPresentationAnchor()
    #endif
  }
}
#endif
