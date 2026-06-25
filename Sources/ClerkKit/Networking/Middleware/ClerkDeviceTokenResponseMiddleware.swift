//
//  ClerkDeviceTokenResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkDeviceTokenResponseMiddleware: ClerkResponseMiddleware {
  private let runtimeScope: ClerkRuntimeScope

  init(runtimeScope: ClerkRuntimeScope) {
    self.runtimeScope = runtimeScope
  }

  func validate(_ response: HTTPURLResponse, data _: Data, for request: URLRequest) async throws {
    guard !request.clerkSuppressesDeviceTokenPersistence else {
      return
    }

    if let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
      try await runtimeScope.withCurrentClerk {
        if let requestGeneration = request.clerkClientResponseGeneration,
           requestGeneration != $0.clientResponseGeneration
        {
          ClerkLogger.debug(
            "Ignoring device token response from stale device token generation. Current generation: \($0.clientResponseGeneration), incoming generation: \(requestGeneration)"
          )
          return
        }

        do {
          try $0.storeDeviceToken(deviceToken)
        } catch {
          ClerkLogger.logError(error, message: "Failed to save device token to keychain")
        }
      }
    }
  }
}
