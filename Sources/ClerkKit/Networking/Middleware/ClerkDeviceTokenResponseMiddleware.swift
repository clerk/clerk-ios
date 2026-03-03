//
//  ClerkDeviceTokenResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkDeviceTokenResponseMiddleware: ClerkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data _: Data, for _: URLRequest) async throws {
    guard let deviceToken = response.value(forHTTPHeaderField: "Authorization") else {
      return
    }

    await emitDeviceToken(deviceToken)
  }

  @MainActor
  private func emitDeviceToken(_ deviceToken: String) {
    Clerk.shared.clerkEventEmitter.send(.deviceTokenReceived(token: deviceToken))
  }
}
