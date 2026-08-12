//
//  MockTrustedDeviceKeyManager.swift
//  Clerk
//

import Foundation

package final class MockTrustedDeviceKeyManager: TrustedDeviceKeyManagerProtocol {
  package nonisolated(unsafe) var isSupportedValue: Bool
  package nonisolated(unsafe) var isSupportedForPolicyHandler: ((TrustedDevicePolicy) -> Bool)?
  package nonisolated(unsafe) var createKeyHandler: ((TrustedDevicePolicy) throws -> TrustedDeviceLocalKey)?
  package nonisolated(unsafe) var signHandler: ((String, String, String?) throws -> TrustedDeviceKeySignature)?
  package nonisolated(unsafe) var hasKeyHandler: ((String) throws -> Bool)?
  package nonisolated(unsafe) var deleteKeyHandler: ((String) throws -> Void)?

  package init(
    isSupported: Bool = true,
    isSupportedForPolicy: ((TrustedDevicePolicy) -> Bool)? = nil,
    createKey: (() throws -> TrustedDeviceLocalKey)? = nil,
    createKeyWithPolicy: ((TrustedDevicePolicy) throws -> TrustedDeviceLocalKey)? = nil,
    sign: ((String, String, String?) throws -> TrustedDeviceKeySignature)? = nil,
    hasKey: ((String) throws -> Bool)? = nil,
    deleteKey: ((String) throws -> Void)? = nil
  ) {
    isSupportedValue = isSupported
    isSupportedForPolicyHandler = isSupportedForPolicy
    if let createKeyWithPolicy {
      createKeyHandler = createKeyWithPolicy
    } else if let createKey {
      createKeyHandler = { _ in try createKey() }
    }
    signHandler = sign
    hasKeyHandler = hasKey
    deleteKeyHandler = deleteKey
  }

  @MainActor
  package func isSupported(policy: TrustedDevicePolicy) -> Bool {
    isSupportedForPolicyHandler?(policy) ?? isSupportedValue
  }

  @MainActor
  package func createKey(policy: TrustedDevicePolicy) throws -> TrustedDeviceLocalKey {
    if let createKeyHandler {
      return try createKeyHandler(policy)
    }
    return .init(
      localKeyId: TrustedDeviceLocalKey.mock.localKeyId,
      publicKeyJWK: TrustedDeviceLocalKey.mock.publicKeyJWK,
      policy: policy
    )
  }

  @MainActor
  package func sign(
    clientData: String,
    localKeyId: String,
    localizedReason: String?
  ) throws -> TrustedDeviceKeySignature {
    if let signHandler {
      return try signHandler(clientData, localKeyId, localizedReason)
    }
    return .init(clientData: clientData, signature: "mock-signature")
  }

  @MainActor
  package func hasKey(localKeyId: String) throws -> Bool {
    if let hasKeyHandler {
      return try hasKeyHandler(localKeyId)
    }
    return true
  }

  @MainActor
  package func deleteKey(localKeyId: String) throws {
    if let deleteKeyHandler {
      try deleteKeyHandler(localKeyId)
    }
  }
}
