//
//  ClerkDeviceTokenResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkDeviceTokenResponseMiddleware: ClerkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data _: Data, for _: URLRequest) async throws {
    if let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
      await Clerk.shared.storeReceivedDeviceToken(deviceToken)
    }
  }
}
