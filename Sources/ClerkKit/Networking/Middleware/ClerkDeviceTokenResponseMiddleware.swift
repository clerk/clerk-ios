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

  func validate(_ response: HTTPURLResponse, data _: Data, for _: URLRequest) async throws {
    if let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
      try await runtimeScope.withCurrentClerk {
        do {
          try $0.storeDeviceToken(deviceToken)
        } catch {
          ClerkLogger.logError(error, message: "Failed to save device token to keychain")
        }
      }
    }
  }
}
