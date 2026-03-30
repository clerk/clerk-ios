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
  private static let continuationManager = WebAuthContinuationManager()
  private static let lifecycleRefreshManager = WebAuthLifecycleRefreshManager()

  let url: URL
  let prefersEphemeralWebBrowserSession: Bool
  private static var currentSession: ASWebAuthenticationSession?

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
          completionHandler: { url, error in
            Task {
              #if os(macOS)
              await WebAuthentication.lifecycleRefreshManager.markPendingForegroundRefreshSuppression()
              #endif
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
        await WebAuthentication.continuationManager.setContinuation(continuation)
        session.start()
      }
    }
  }

  static func finishWithDeeplinkUrl(url: URL) {
    Task {
      #if os(macOS)
      await lifecycleRefreshManager.markPendingForegroundRefreshSuppression()
      #endif
      await continuationManager.completeSession(with: url, error: nil)

      #if targetEnvironment(macCatalyst)
      // mac catalyst web auth window doesn't close without
      // this when the callback is intercepted as a universal link
      currentSession?.cancel()
      #endif

      currentSession = nil
    }
  }

  static func cancelCurrentSession() async {
    #if !os(tvOS)
    currentSession?.cancel()
    #endif

    currentSession = nil

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
    PresentationAnchorProvider.current
  }
}

#endif
