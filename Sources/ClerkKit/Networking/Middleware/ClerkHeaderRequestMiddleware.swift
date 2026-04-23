//
//  ClerkHeaderRequestMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkHeaderRequestMiddleware: ClerkRequestMiddleware {
  private let keychainProvider: @MainActor @Sendable () -> any KeychainStorage
  private let clientIdProvider: @MainActor @Sendable () -> String?

  init(
    keychainProvider: @escaping @MainActor @Sendable () -> any KeychainStorage = { Clerk.shared.dependencies.keychain },
    clientIdProvider: @escaping @MainActor @Sendable () -> String? = { Clerk.shared.client?.id }
  ) {
    self.keychainProvider = keychainProvider
    self.clientIdProvider = clientIdProvider
  }

  @MainActor
  func prepare(_ request: inout URLRequest) async throws {
    let keychain = keychainProvider()

    if let deviceToken = try? keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) {
      request.setValue(deviceToken, forHTTPHeaderField: "Authorization")
    }

    if let clientId = clientIdProvider() {
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
