//
//  ClerkProxyRequestMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 2/13/25.
//

import Foundation

struct ClerkProxyRequestMiddleware: NetworkRequestMiddleware {
  @MainActor
  func prepare(_ request: inout URLRequest) async throws {
    let proxyConfiguration = Clerk.shared.proxyConfiguration

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
