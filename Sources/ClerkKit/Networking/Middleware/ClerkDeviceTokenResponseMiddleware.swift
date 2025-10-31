//
//  ClerkDeviceTokenResponseMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import FactoryKit
import Foundation

struct ClerkDeviceTokenResponseMiddleware: NetworkResponseMiddleware {
  private var keychain: any KeychainStorage { Container.shared.keychain() }

  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) throws {
    if let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
      try? keychain.set(deviceToken, forKey: "clerkDeviceToken")
    }
  }
}
