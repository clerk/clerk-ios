//
//  ClerkHeaderRequestMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct ClerkHeaderRequestMiddleware: NetworkRequestMiddleware {
  @MainActor
  private var keychain: any KeychainStorage { Clerk.shared.dependencies.keychain }

  @MainActor
  func prepare(_ request: inout URLRequest) async throws {
    if let deviceToken = try? keychain.string(forKey: "clerkDeviceToken") {
      request.setValue(deviceToken, forHTTPHeaderField: "Authorization")
    }

    if let clientId = Clerk.shared.client?.id {
      request.setValue(clientId, forHTTPHeaderField: "x-clerk-client-id")
    }

    if let deviceId = DeviceHelper.deviceID {
      request.setValue(deviceId, forHTTPHeaderField: "x-native-device-id")
    }

    request.setValue(DeviceHelper.deviceType, forHTTPHeaderField: "x-device-type")
    request.setValue(DeviceHelper.deviceModel, forHTTPHeaderField: "x-device-model")
    request.setValue(DeviceHelper.osVersion, forHTTPHeaderField: "x-os-version")
    request.setValue(DeviceHelper.appVersion, forHTTPHeaderField: "x-app-version")
    request.setValue(DeviceHelper.bundleID, forHTTPHeaderField: "x-bundle-id")
    request.setValue(DeviceHelper.isSandbox, forHTTPHeaderField: "x-is-sandbox")
  }
}
