//
//  ClerkDeviceTokenResponseMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct ClerkDeviceTokenResponseMiddleware: NetworkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data _: Data, for _: URLRequest) throws {
    if let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
      // Emit event on MainActor - listeners will handle saving and syncing
      if Thread.isMainThread {
        MainActor.assumeIsolated {
          Clerk.shared.clerkEventEmitter.send(.deviceTokenReceived(token: deviceToken))
        }
      } else {
        Task { @MainActor in
          Clerk.shared.clerkEventEmitter.send(.deviceTokenReceived(token: deviceToken))
        }
      }
    }
  }
}
