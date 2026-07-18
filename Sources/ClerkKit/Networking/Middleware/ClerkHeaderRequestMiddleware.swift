//
//  ClerkHeaderRequestMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkHeaderRequestMiddleware: ClerkRequestMiddleware {
  static let skipClientIdHeader = "X-Clerk-SDK-Skip-Client-Id"
  static let canonicalClientRequestHeader = "X-Clerk-SDK-Canonical-Client-Request"

  private let runtimeScope: ClerkRuntimeScope

  init(runtimeScope: ClerkRuntimeScope) {
    self.runtimeScope = runtimeScope
  }

  @MainActor
  func prepare(_ request: inout URLRequest) async throws {
    let clerk = try runtimeScope.requireCurrentClerk()
    let identity: SharedSessionRequestIdentitySnapshot
    if let coordinator = clerk.sharedSessionSyncCoordinator {
      try await coordinator.waitForInitialReconciliation()
      await clerk.waitForPendingLocalIdentityOperations()
      identity = try await coordinator.captureRequestIdentity()
    } else {
      identity = try await clerk.captureLocalRequestIdentity()
    }
    _ = try runtimeScope.requireCurrentClerk()
    request.setClerkClientResponseGeneration(identity.clientResponseGeneration)
    request.setClerkSharedSessionBaseGeneration(identity.baseGeneration)
    let isCanonicalClientRequest = request.value(
      forHTTPHeaderField: Self.canonicalClientRequestHeader
    ) == "1"
    request.setClerkCanonicalClientRequest(isCanonicalClientRequest)
    request.setValue(nil, forHTTPHeaderField: Self.canonicalClientRequestHeader)
    let skipClientId = request.value(forHTTPHeaderField: Self.skipClientIdHeader) == "1"
    request.setValue(nil, forHTTPHeaderField: Self.skipClientIdHeader)

    if let deviceToken = identity.deviceToken {
      request.setValue(deviceToken, forHTTPHeaderField: "Authorization")
    }

    if !skipClientId, let clientId = identity.clientID {
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
