//
//  ClerkHeaderRequestMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import FactoryKit
import Foundation

struct ClerkHeaderRequestMiddleware: NetworkRequestMiddleware {
  private var keychain: any KeychainStorage { Container.shared.keychain() }

  @MainActor
  func prepare(_ request: inout URLRequest) async throws {
  if let deviceToken = try? keychain.string(forKey: "clerkDeviceToken") {
    request.setValue(deviceToken, forHTTPHeaderField: "Authorization")
  }

  if Clerk.shared.options.debugMode, let clientId = Clerk.shared.client?.id {
    request.setValue(clientId, forHTTPHeaderField: "x-clerk-client-id")
  }

  request.setValue(deviceID, forHTTPHeaderField: "x-native-device-id")
  }
}
