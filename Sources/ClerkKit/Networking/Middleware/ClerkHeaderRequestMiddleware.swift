//
//  ClerkHeaderRequestMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkHeaderRequestMiddleware: ClerkRequestMiddleware {
  static let skipClientIdHeader = "X-Clerk-SDK-Skip-Client-Id"

  private let runtimeScope: ClerkRuntimeScope

  init(runtimeScope: ClerkRuntimeScope) {
    self.runtimeScope = runtimeScope
  }

  @MainActor
  func prepare(_ request: inout URLRequest) async throws {
    let clerk = try runtimeScope.requireCurrentClerk()
    let deviceToken = clerk.deviceToken
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)
    let skipClientId = request.value(forHTTPHeaderField: Self.skipClientIdHeader) == "1"
    request.setValue(nil, forHTTPHeaderField: Self.skipClientIdHeader)

    if let deviceToken {
      request.setValue(deviceToken, forHTTPHeaderField: "Authorization")
    }

    if !skipClientId,
       clerk.sharedSessionSyncCoordinator?.requiresClientRefresh != true,
       let clientId = clerk.client?.id
    {
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
