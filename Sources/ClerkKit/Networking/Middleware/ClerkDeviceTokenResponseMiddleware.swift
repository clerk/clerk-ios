//
//  ClerkDeviceTokenResponseMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import FactoryKit
import Foundation

struct ClerkDeviceTokenResponseMiddleware: NetworkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) throws {
    if let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
      try? Container.shared.keychain().set(deviceToken, forKey: "clerkDeviceToken")
    }
  }
}
