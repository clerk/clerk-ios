//
//  ClerkDeviceTokenResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkDeviceTokenResponseMiddleware: ClerkAsyncResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data _: Data, for _: URLRequest) async throws {
    guard let deviceToken = response.value(forHTTPHeaderField: "Authorization") else {
      return
    }

    await MainActor.run {
      Clerk.shared.clerkEventEmitter.send(.deviceTokenReceived(token: deviceToken))
    }
  }
}
