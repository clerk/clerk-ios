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
      // If we're on the main thread (e.g., in tests), execute synchronously using assumeIsolated
      // Otherwise, use Task to hop to MainActor
      if Thread.isMainThread {
        MainActor.assumeIsolated {
          try? Clerk.shared.dependencies.keychain.set(deviceToken, forKey: "clerkDeviceToken")
        }
      } else {
        Task { @MainActor in
          try? Clerk.shared.dependencies.keychain.set(deviceToken, forKey: "clerkDeviceToken")
        }
      }
    }
  }
}
