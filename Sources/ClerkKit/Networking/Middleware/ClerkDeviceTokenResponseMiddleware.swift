//
//  ClerkDeviceTokenResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkDeviceTokenResponseMiddleware: ClerkResponseMiddleware {
  private let runtimeScope: ClerkRuntimeScope

  init(runtimeScope: ClerkRuntimeScope = .init()) {
    self.runtimeScope = runtimeScope
  }

  func validate(_ response: HTTPURLResponse, data _: Data, for _: URLRequest) async throws {
    if let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
      try await runtimeScope.withCurrentClerk {
        $0.storeReceivedDeviceToken(deviceToken)
      }
    }
  }
}
