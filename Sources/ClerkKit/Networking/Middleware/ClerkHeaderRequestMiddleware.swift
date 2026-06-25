//
//  ClerkHeaderRequestMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkHeaderRequestMiddleware: ClerkRequestMiddleware {
  static let skipClientIdHeader = "X-Clerk-SDK-Skip-Client-Id"
  static let suppressDeviceTokenPersistenceHeader = "X-Clerk-SDK-Suppress-Device-Token-Persistence"

  private let runtimeScope: ClerkRuntimeScope

  init(runtimeScope: ClerkRuntimeScope) {
    self.runtimeScope = runtimeScope
  }

  @MainActor
  func prepare(_ request: inout URLRequest) async throws {
    let clerk = try runtimeScope.requireCurrentClerk()
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)
    let skipClientId = request.value(forHTTPHeaderField: Self.skipClientIdHeader) == "1"
    request.setValue(nil, forHTTPHeaderField: Self.skipClientIdHeader)
    let suppressDeviceTokenPersistence = request.value(forHTTPHeaderField: Self.suppressDeviceTokenPersistenceHeader) == "1"
    request.setValue(nil, forHTTPHeaderField: Self.suppressDeviceTokenPersistenceHeader)
    if suppressDeviceTokenPersistence {
      request.setClerkSuppressesDeviceTokenPersistence(true)
    }

    if let deviceToken = try? clerk.dependencies.keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) {
      request.setValue(deviceToken, forHTTPHeaderField: "Authorization")
    }

    if !skipClientId, let clientId = clerk.client?.id {
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
