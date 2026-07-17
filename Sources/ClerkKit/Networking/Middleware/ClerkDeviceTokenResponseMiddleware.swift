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

  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
    guard let deviceToken = response.value(forHTTPHeaderField: "Authorization") else {
      return
    }

    guard !ClerkClientSyncResponseMiddleware.containsClientUpdate(in: data) else {
      return
    }

    try await runtimeScope.withCurrentClerk {
      if let requestGeneration = request.clerkClientResponseGeneration,
         requestGeneration != $0.clientResponseGeneration
      {
        ClerkLogger.debug(
          "Ignoring device token response from a superseded identity generation. Current generation: \($0.clientResponseGeneration), incoming generation: \(requestGeneration)"
        )
        return
      }

      do {
        try $0.storeDeviceToken(deviceToken)
        try $0.sharedSessionSyncCoordinator?.persistCurrentIdentityIfNeeded()
      } catch {
        ClerkLogger.logError(error, message: "Failed to save device token to keychain")
      }
    }
  }
}
