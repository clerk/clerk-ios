#if !os(watchOS)
import AuthenticationServices
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ClerkJSOAuthError: Error, Equatable {
  var code: String
  var message: String

  var json: String {
    let payload = ["code": code, "message": message]
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let text = String(data: data, encoding: .utf8)
    else {
      return "{\"code\":\"oauth_session_failed\",\"message\":\"OAuth session failed\"}"
    }
    return text
  }

  static let invalidURL = ClerkJSOAuthError(
    code: "oauth_invalid_url",
    message: "Invalid OAuth verification URL"
  )
  static let invalidRedirect = ClerkJSOAuthError(
    code: "oauth_invalid_redirect",
    message: "OAuth redirect URL must use a custom scheme"
  )
  static let cancelled = ClerkJSOAuthError(
    code: "oauth_cancelled",
    message: "The user cancelled the authentication session."
  )
  static let startFailed = ClerkJSOAuthError(
    code: "oauth_session_failed",
    message: "Unable to start web authentication session."
  )

  static func from(_ error: Error) -> ClerkJSOAuthError {
    if error is CancellationError {
      return .cancelled
    }
    if let oauth = error as? ClerkJSOAuthError {
      return oauth
    }
    let nsError = error as NSError
    if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
    {
      return .cancelled
    }
    return ClerkJSOAuthError(code: "oauth_session_failed", message: error.localizedDescription)
  }
}

final class ClerkJSOAuthSession: NSObject, @unchecked Sendable {
  typealias SessionFactory = @MainActor (
    URL,
    String?,
    @escaping ASWebAuthenticationSession.CompletionHandler
  ) -> ASWebAuthenticationSession

  var redirectURL: URL
  var prefersEphemeralWebBrowserSession = false
  var sessionFactory: SessionFactory
  private var session: ASWebAuthenticationSession?
  private var continuation: CheckedContinuation<URL, Error>?

  init(
    redirectURL: URL = ClerkJSRuntime.defaultOAuthRedirectURL,
    sessionFactory: @escaping SessionFactory = ClerkJSOAuthSession.makeSession
  ) {
    self.redirectURL = redirectURL
    self.sessionFactory = sessionFactory
  }

  static func makeSession(
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

  static func callbackScheme(from redirectURL: URL) -> String? {
    guard let scheme = redirectURL.scheme, !scheme.isEmpty else {
      return nil
    }
    switch scheme.lowercased() {
    case "http", "https", "file", "javascript", "data":
      return nil
    default:
      return scheme
    }
  }

  static func parseOpenURL(_ href: String) -> Result<URL, ClerkJSOAuthError> {
    guard let url = URL(string: href),
          let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme),
          url.host != nil
    else {
      return .failure(.invalidURL)
    }
    return .success(url)
  }

  func open(href: String, prefersEphemeralSession: Bool? = nil) async -> Result<String, ClerkJSOAuthError> {
    switch Self.parseOpenURL(href) {
    case .failure(let error):
      return .failure(error)
    case .success(let url):
      guard Self.callbackScheme(from: redirectURL) != nil else {
        return .failure(.invalidRedirect)
      }
      do {
        let callback = try await perform(url, prefersEphemeralSession: prefersEphemeralSession)
        return .success(callback.absoluteString)
      } catch {
        return .failure(.from(error))
      }
    }
  }

  func cancel() {
    Task { @MainActor [weak self] in
      self?.cancelOnMain()
    }
  }

  @MainActor
  private func perform(_ url: URL, prefersEphemeralSession: Bool?) async throws -> URL {
    cancelOnMain()
    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      let scheme = Self.callbackScheme(from: redirectURL)
      let session = sessionFactory(url, scheme) { [weak self] callbackURL, error in
        Task { @MainActor in
          self?.complete(url: callbackURL, error: error)
        }
      }
      #if !os(tvOS)
      session.prefersEphemeralWebBrowserSession = prefersEphemeralSession ?? prefersEphemeralWebBrowserSession
      session.presentationContextProvider = self
      #endif
      self.session = session
      guard session.start() else {
        complete(url: nil, error: ClerkJSOAuthError.startFailed)
        return
      }
    }
  }

  @MainActor
  private func cancelOnMain() {
    session?.cancel()
    session = nil
    guard let continuation else {
      return
    }
    self.continuation = nil
    continuation.resume(throwing: CancellationError())
  }

  @MainActor
  private func complete(url: URL?, error: Error?) {
    session = nil
    guard let continuation else {
      return
    }
    self.continuation = nil
    if let url {
      continuation.resume(returning: url)
    } else if let error {
      continuation.resume(throwing: error)
    } else {
      continuation.resume(throwing: ClerkJSOAuthError.startFailed)
    }
  }
}

#if !os(tvOS)
extension ClerkJSOAuthSession: ASWebAuthenticationPresentationContextProviding {
  func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
    #if canImport(UIKit) && !os(macOS)
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    return windows.first(where: \.isKeyWindow) ?? windows.first ?? ASPresentationAnchor()
    #elseif canImport(AppKit)
    return NSApplication.shared.keyWindow
      ?? NSApplication.shared.mainWindow
      ?? NSApplication.shared.windows.first
      ?? ASPresentationAnchor()
    #else
    return ASPresentationAnchor()
    #endif
  }
}
#endif
#endif
