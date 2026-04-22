//
//  ClerkURLRoute.swift
//  Clerk
//

import Foundation

enum ClerkURLRoute: Hashable {
  case magicLink(flowId: String, approvalToken: String)

  @MainActor
  init?(url: URL) throws {
    if Self.matches(
      url,
      redirectUrl: Clerk.shared.options.redirectConfig.redirectUrl,
      requiredParams: MagicLinkCallback.requiredParams
    ) {
      let callback = try MagicLinkCallback(url: url)
      self = .magicLink(
        flowId: callback.flowId,
        approvalToken: callback.approvalToken
      )
      return
    }

    return nil
  }

  private static func matches(
    _ url: URL,
    redirectUrl: String,
    requiredParams: Set<String>
  ) -> Bool {
    guard
      let actual = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let expected = URLComponents(string: redirectUrl),
      normalizedScheme(actual.scheme) == normalizedScheme(expected.scheme)
    else {
      return false
    }

    if expected.isHTTPRedirect {
      guard
        normalizedHost(actual.host) == normalizedHost(expected.host),
        normalizedPath(actual.path) == normalizedPath(expected.path)
      else {
        return false
      }
    }

    return requiredParams.allSatisfy { requiredParam in
      url.queryParam(named: requiredParam) != nil
    }
  }

  private static func normalizedScheme(_ scheme: String?) -> String? {
    scheme?.lowercased()
  }

  private static func normalizedHost(_ host: String?) -> String? {
    host?.lowercased()
  }

  private static func normalizedPath(_ path: String) -> String {
    if path.isEmpty || path == "/" {
      return ""
    }

    return path
  }
}

extension URLComponents {
  fileprivate var isHTTPRedirect: Bool {
    switch scheme?.lowercased() {
    case "http", "https":
      true
    default:
      false
    }
  }
}
