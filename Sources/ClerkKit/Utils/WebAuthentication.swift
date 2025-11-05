//
//  WebAuthentication.swift
//
//
//  Created by Mike Pitre on 10/19/23.
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
}

@available(tvOS 16.0, watchOS 6.2, *)
@MainActor
final class WebAuthentication: NSObject {
  private static let continuationManager = WebAuthContinuationManager()

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
      await continuationManager.completeSession(with: url, error: nil)

      #if targetEnvironment(macCatalyst)
      // mac catalyst web auth window doesn't close without
      // this when the callback is intercepted as a universal link
      currentSession?.cancel()
      #endif

      currentSession = nil
    }
  }
}

#if !os(watchOS) && !os(tvOS)
extension WebAuthentication: ASWebAuthenticationPresentationContextProviding {
  @MainActor
  func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
    #if os(iOS)
    UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    #else
    ASPresentationAnchor()
    #endif
  }
}

#endif
