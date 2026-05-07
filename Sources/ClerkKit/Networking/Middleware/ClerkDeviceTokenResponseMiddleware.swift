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
      let clerk = try await runtimeScope.requireCurrentClerk()
      await clerk.storeReceivedDeviceToken(deviceToken)
    }
  }
}
