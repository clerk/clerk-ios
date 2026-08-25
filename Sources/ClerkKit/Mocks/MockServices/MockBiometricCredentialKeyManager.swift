//
//  MockBiometricCredentialKeyManager.swift
//  Clerk
//

import Foundation

package final class MockBiometricCredentialKeyManager: BiometricCredentialKeyManagerProtocol {
  package nonisolated(unsafe) var isSupportedValue: Bool
  package nonisolated(unsafe) var isSupportedForPolicyHandler: ((BiometricCredentialPolicy) -> Bool)?
  package nonisolated(unsafe) var createKeyHandler: ((BiometricCredentialPolicy) throws -> BiometricCredentialLocalKey)?
  package nonisolated(unsafe) var signHandler: ((String, String, String?) throws -> BiometricCredentialKeySignature)?
  package nonisolated(unsafe) var hasKeyHandler: ((String) throws -> Bool)?
  package nonisolated(unsafe) var deleteKeyHandler: ((String) throws -> Void)?

  package init(
    isSupported: Bool = true,
    isSupportedForPolicy: ((BiometricCredentialPolicy) -> Bool)? = nil,
    createKey: (() throws -> BiometricCredentialLocalKey)? = nil,
    createKeyWithPolicy: ((BiometricCredentialPolicy) throws -> BiometricCredentialLocalKey)? = nil,
    sign: ((String, String, String?) throws -> BiometricCredentialKeySignature)? = nil,
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
  package func isSupported(policy: BiometricCredentialPolicy) -> Bool {
    isSupportedForPolicyHandler?(policy) ?? isSupportedValue
  }

  @MainActor
  package func createKey(policy: BiometricCredentialPolicy) throws -> BiometricCredentialLocalKey {
    if let createKeyHandler {
      return try createKeyHandler(policy)
    }
    return .init(
      localKeyId: BiometricCredentialLocalKey.mock.localKeyId,
      publicKeyJWK: BiometricCredentialLocalKey.mock.publicKeyJWK,
      policy: policy
    )
  }

  @MainActor
  package func sign(
    clientData: String,
    localKeyId: String,
    localizedReason: String?
  ) throws -> BiometricCredentialKeySignature {
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
