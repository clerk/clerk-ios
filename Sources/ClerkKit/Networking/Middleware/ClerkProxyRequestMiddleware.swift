//
//  ClerkProxyRequestMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkProxyRequestMiddleware: ClerkRequestMiddleware {
  private let runtimeScope: ClerkRuntimeScope

  init(runtimeScope: ClerkRuntimeScope) {
    self.runtimeScope = runtimeScope
  }

  @MainActor
  func prepare(_ request: inout URLRequest) async throws {
    let proxyConfiguration = try runtimeScope.requireCurrentClerk().proxyConfiguration

    guard
      let proxyConfiguration,
      !proxyConfiguration.pathSegments.isEmpty,
      let url = request.url,
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
      return
    }

    let currentPath = components.path
    let updatedPath = proxyConfiguration.prefixedPath(for: currentPath)

    guard currentPath != updatedPath else {
      return
    }

    components.path = updatedPath

    if let updatedURL = components.url {
      request.url = updatedURL
    }
  }
}
