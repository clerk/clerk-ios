//
//  ClerkDeviceTokenRequestProcessor.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import FactoryKit
import Foundation

struct ClerkDeviceTokenRequestProcessor: RequestPostprocessor {
  static func process(response: HTTPURLResponse, data _: Data, task _: URLSessionTask) throws {
    if let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
      try? Container.shared.keychain().set(deviceToken, forKey: "clerkDeviceToken")
    }
  }
}
