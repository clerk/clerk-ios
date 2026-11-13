//
//  SessionTransfer.swift
//  Clerk
//

import Foundation

/// Where a session transfer URL will be opened.
public enum SessionTransferPresentation: String, Codable, Sendable {
  /// A web view that the app renders, such as a `WKWebView`.
  case webView = "webview"

  /// The system browser.
  case browser
}

/// A one-time URL that signs the active session's user in on a web page.
///
/// Open ``url`` once, within a minute of creating it. Never log, store, or share it, because anyone
/// who opens it first is signed in as the user. Its descriptions leave the URL out, so printing or
/// dumping a `SessionTransfer` doesn't reveal it.
public struct SessionTransfer: Sendable, Equatable {
  /// The URL that redeems the transfer and then loads the destination.
  public let url: URL

  /// When ``url`` stops working.
  public let expiresAt: Date
}

extension SessionTransfer: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
  public var description: String {
    "SessionTransfer(url: \(ClerkLogRedaction.placeholder), expiresAt: \(expiresAt))"
  }

  public var debugDescription: String {
    description
  }

  public var customMirror: Mirror {
    Mirror(self, children: ["expiresAt": expiresAt], displayStyle: .struct)
  }
}

struct SessionTransferCreateParams: Encodable {
  let redirectUrl: String
  let presentationMode: SessionTransferPresentation

  init(destination: URL, presentation: SessionTransferPresentation) throws {
    guard
      let scheme = destination.scheme?.lowercased(),
      scheme == "https" || scheme == "http",
      destination.host?.isEmpty == false
    else {
      throw ClerkClientError(message: "Session transfer requires an absolute http or https destination URL.", localizationBundle: .module)
    }
    redirectUrl = destination.absoluteString
    presentationMode = presentation
  }
}

struct SessionTransferResource: Codable {
  let object: String
  let url: String
  let expiresAt: Date

  func sessionTransfer() throws -> SessionTransfer {
    guard
      object == "session_transfer",
      let components = URLComponents(string: url),
      components.scheme?.lowercased() == "https",
      components.host?.isEmpty == false,
      components.user == nil,
      components.password == nil,
      let url = components.url
    else {
      throw ClerkClientError(message: "Session transfer creation returned an invalid response.", localizationBundle: .module)
    }
    return SessionTransfer(url: url, expiresAt: expiresAt)
  }
}
