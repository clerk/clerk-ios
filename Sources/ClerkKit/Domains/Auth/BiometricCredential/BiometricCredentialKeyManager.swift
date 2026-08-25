//
//  BiometricCredentialKeyManager.swift
//  Clerk
//

import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif
import Security

extension BiometricCredentialKeyManagerProtocol {
  @MainActor
  var isSupported: Bool {
    isSupported(policy: .biometryCurrentSet)
  }

  @MainActor
  func createKey() throws -> BiometricCredentialLocalKey {
    try createKey(policy: .biometryCurrentSet)
  }

  @MainActor
  func sign(clientData: String, localKeyId: String) throws -> BiometricCredentialKeySignature {
    try sign(clientData: clientData, localKeyId: localKeyId, localizedReason: nil)
  }
}

final class BiometricCredentialKeyManager: BiometricCredentialKeyManagerProtocol {
  private static let applicationTagPrefix = "dev.clerk.trusted_device"

  @MainActor
  func isSupported(policy: BiometricCredentialPolicy) -> Bool {
    #if (os(iOS) || os(macOS)) && canImport(LocalAuthentication)
    let context = LAContext()
    var error: NSError?
    return context.canEvaluatePolicy(Self.localAuthenticationPolicy(for: policy), error: &error)
    #else
    return false
    #endif
  }

  @MainActor
  func createKey(policy: BiometricCredentialPolicy = .biometryCurrentSet) throws -> BiometricCredentialLocalKey {
    #if (os(iOS) || os(macOS)) && canImport(LocalAuthentication)
    guard canCreateKey(policy: policy) else {
      throw BiometricCredentialKeyManagerError.biometricAuthenticationUnavailable
    }

    let localKeyId = Self.makeLocalKeyId()
    let accessControl = try Self.makeAccessControl(policy: policy)
    let attributes = Self.makePrivateKeyAttributes(localKeyId: localKeyId, accessControl: accessControl)

    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      throw BiometricCredentialKeyManagerError.keyGenerationFailed(Self.errorMessage(from: error))
    }

    return try Self.completeKeyCreation(
      localKeyId: localKeyId,
      policy: policy,
      exportPublicKeyJWK: {
        try Self.publicKeyJWK(for: privateKey)
      },
      deleteKey: deleteKey(localKeyId:)
    )
    #else
    throw BiometricCredentialKeyManagerError.unsupportedPlatform
    #endif
  }

  @MainActor
  private func canCreateKey(policy: BiometricCredentialPolicy) -> Bool {
    #if (os(iOS) || os(macOS)) && canImport(LocalAuthentication)
    let context = LAContext()
    var error: NSError?
    return context.canEvaluatePolicy(Self.localAuthenticationPolicyForKeyCreation(for: policy), error: &error)
    #else
    return false
    #endif
  }

  @MainActor
  func sign(
    clientData: String,
    localKeyId: String,
    localizedReason: String? = nil
  ) throws -> BiometricCredentialKeySignature {
    let privateKey = try privateKey(localKeyId: localKeyId, localizedReason: localizedReason)
    let algorithm = SecKeyAlgorithm.ecdsaSignatureMessageX962SHA256
    guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
      throw BiometricCredentialKeyManagerError.unsupportedAlgorithm
    }

    var error: Unmanaged<CFError>?
    guard let signature = SecKeyCreateSignature(
      privateKey,
      algorithm,
      Data(clientData.utf8) as CFData,
      &error
    ) as Data? else {
      throw BiometricCredentialKeyManagerError.signingFailed(Self.errorMessage(from: error))
    }

    let rawSignature = try Self.rawES256Signature(fromDEREncoded: signature)

    return BiometricCredentialKeySignature(
      clientData: clientData,
      signature: Self.base64URLEncodedString(rawSignature)
    )
  }

  @MainActor
  func hasKey(localKeyId: String) throws -> Bool {
    var query = Self.privateKeyQuery(localKeyId: localKeyId)
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    let status = SecItemCopyMatching(query as CFDictionary, nil)
    switch status {
    case errSecSuccess:
      return true
    case errSecItemNotFound:
      return false
    default:
      throw KeychainError.unexpectedStatus(status)
    }
  }

  @MainActor
  func deleteKey(localKeyId: String) throws {
    let status = SecItemDelete(Self.privateKeyQuery(localKeyId: localKeyId) as CFDictionary)
    switch status {
    case errSecSuccess, errSecItemNotFound:
      return
    default:
      throw BiometricCredentialKeyManagerError.deletionFailed(status)
    }
  }

  private func privateKey(localKeyId: String, localizedReason: String?) throws -> SecKey {
    var query = Self.privateKeyQuery(localKeyId: localKeyId)
    query[kSecReturnRef as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    #if (os(iOS) || os(macOS)) && canImport(LocalAuthentication)
    let context = LAContext()
    if let localizedReason {
      context.localizedReason = localizedReason
    }
    query[kSecUseAuthenticationContext as String] = context
    #endif

    var privateKey: SecKey?
    let status = withUnsafeMutablePointer(to: &privateKey) { pointer in
      pointer.withMemoryRebound(to: CFTypeRef?.self, capacity: 1) { reboundPointer in
        SecItemCopyMatching(query as CFDictionary, reboundPointer)
      }
    }

    switch status {
    case errSecSuccess:
      guard let privateKey else {
        throw BiometricCredentialKeyManagerError.keyNotFound
      }
      return privateKey
    case errSecItemNotFound:
      throw BiometricCredentialKeyManagerError.keyNotFound
    default:
      throw Self.privateKeyLookupError(for: status)
    }
  }

  private static func makeLocalKeyId() -> String {
    "tdlk_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  }

  package static func accessControlFlags(for policy: BiometricCredentialPolicy) -> SecAccessControlCreateFlags {
    switch policy {
    case .biometryCurrentSet:
      [.privateKeyUsage, .biometryCurrentSet]
    case .biometryAny:
      [.privateKeyUsage, .biometryAny]
    case .biometryOrDevicePasscode:
      [.privateKeyUsage, .userPresence]
    }
  }

  package static func makeAccessControl(policy: BiometricCredentialPolicy = .biometryCurrentSet) throws -> SecAccessControl {
    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
      accessControlFlags(for: policy),
      &error
    ) else {
      throw BiometricCredentialKeyManagerError.keyGenerationFailed(errorMessage(from: error))
    }

    return accessControl
  }

  package static func makePrivateKeyAttributes(
    localKeyId: String,
    accessControl: SecAccessControl
  ) -> [String: Any] {
    var attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: applicationTag(localKeyId: localKeyId),
        kSecAttrAccessControl as String: accessControl,
      ],
    ]

    #if os(macOS)
    attributes[kSecUseDataProtectionKeychain as String] = kCFBooleanTrue
    #endif

    return attributes
  }

  package static func privateKeyQuery(localKeyId: String) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrApplicationTag as String: applicationTag(localKeyId: localKeyId),
    ]

    #if os(macOS)
    query[kSecUseDataProtectionKeychain as String] = kCFBooleanTrue
    #endif

    return query
  }

  package static func privateKeyLookupError(for status: OSStatus) -> Error {
    switch status {
    case errSecUserCanceled:
      BiometricCredentialKeyManagerError.biometricAuthenticationCanceled
    case errSecAuthFailed:
      BiometricCredentialKeyManagerError.biometricAuthenticationFailed
    case errSecInteractionNotAllowed:
      BiometricCredentialKeyManagerError.biometricAuthenticationUnavailable
    default:
      KeychainError.unexpectedStatus(status)
    }
  }

  package static func publicKeyJWK(fromX963Representation representation: Data) throws -> String {
    guard representation.count == 65, representation.first == 0x04 else {
      throw BiometricCredentialKeyManagerError.invalidPublicKey
    }

    let xCoordinate = representation[1 ..< 33]
    let yCoordinate = representation[33 ..< 65]
    return """
    {"kty":"EC","crv":"P-256","x":"\(base64URLEncodedString(xCoordinate))","y":"\(base64URLEncodedString(yCoordinate))","alg":"ES256"}
    """
  }

  @MainActor
  package static func completeKeyCreation(
    localKeyId: String,
    policy: BiometricCredentialPolicy,
    exportPublicKeyJWK: () throws -> String,
    deleteKey: (String) throws -> Void
  ) throws -> BiometricCredentialLocalKey {
    do {
      return try BiometricCredentialLocalKey(
        localKeyId: localKeyId,
        publicKeyJWK: exportPublicKeyJWK(),
        policy: policy
      )
    } catch {
      let exportError = error
      do {
        try deleteKey(localKeyId)
      } catch {
        ClerkLogger.logError(
          error,
          message: "Failed to delete biometric-credential key after public-key export failed."
        )
      }
      throw exportError
    }
  }

  package static func base64URLEncodedString(_ data: some DataProtocol) -> String {
    Data(data)
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  package static func rawES256Signature(fromDEREncoded signature: Data) throws -> Data {
    let bytes = Array(signature)
    var offset = 0

    guard try readDERByte(bytes, offset: &offset) == 0x30 else {
      throw invalidES256SignatureError()
    }

    let sequenceLength = try readDERLength(bytes, offset: &offset)
    guard sequenceLength == bytes.count - offset else {
      throw invalidES256SignatureError()
    }

    let rComponent = try readDERInteger(bytes, offset: &offset)
    let sComponent = try readDERInteger(bytes, offset: &offset)
    guard offset == bytes.count else {
      throw invalidES256SignatureError()
    }

    var raw = try paddedES256Component(rComponent)
    try raw.append(paddedES256Component(sComponent))
    return raw
  }

  private static func publicKeyJWK(for privateKey: SecKey) throws -> String {
    guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
      throw BiometricCredentialKeyManagerError.publicKeyExportFailed("Unable to copy public key.")
    }

    var error: Unmanaged<CFError>?
    guard let representation = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
      throw BiometricCredentialKeyManagerError.publicKeyExportFailed(errorMessage(from: error))
    }

    return try publicKeyJWK(fromX963Representation: representation)
  }

  #if (os(iOS) || os(macOS)) && canImport(LocalAuthentication)
  package static func localAuthenticationPolicy(for policy: BiometricCredentialPolicy) -> LAPolicy {
    switch policy {
    case .biometryCurrentSet, .biometryAny:
      .deviceOwnerAuthenticationWithBiometrics
    case .biometryOrDevicePasscode:
      .deviceOwnerAuthentication
    }
  }

  package static func localAuthenticationPolicyForKeyCreation(for policy: BiometricCredentialPolicy) -> LAPolicy {
    switch policy {
    case .biometryCurrentSet, .biometryAny, .biometryOrDevicePasscode:
      .deviceOwnerAuthenticationWithBiometrics
    }
  }
  #endif

  private static func applicationTag(localKeyId: String) -> Data {
    Data("\(applicationTagPrefix).\(localKeyId)".utf8)
  }

  private static func readDERByte(_ bytes: [UInt8], offset: inout Int) throws -> UInt8 {
    guard offset < bytes.count else {
      throw invalidES256SignatureError()
    }

    let byte = bytes[offset]
    offset += 1
    return byte
  }

  private static func readDERLength(_ bytes: [UInt8], offset: inout Int) throws -> Int {
    let first = try readDERByte(bytes, offset: &offset)
    if first & 0x80 == 0 {
      return Int(first)
    }

    let byteCount = Int(first & 0x7F)
    guard byteCount > 0, byteCount <= MemoryLayout<Int>.size, byteCount <= bytes.count - offset else {
      throw invalidES256SignatureError()
    }

    var length = 0
    for _ in 0 ..< byteCount {
      length = try (length << 8) | Int(readDERByte(bytes, offset: &offset))
    }
    return length
  }

  private static func readDERInteger(_ bytes: [UInt8], offset: inout Int) throws -> [UInt8] {
    guard try readDERByte(bytes, offset: &offset) == 0x02 else {
      throw invalidES256SignatureError()
    }

    let length = try readDERLength(bytes, offset: &offset)
    guard length > 0, length <= bytes.count - offset else {
      throw invalidES256SignatureError()
    }

    let value = Array(bytes[offset ..< offset + length])
    offset += length
    return value
  }

  private static func paddedES256Component(_ bytes: [UInt8]) throws -> Data {
    guard let first = bytes.first, first & 0x80 == 0 else {
      throw invalidES256SignatureError()
    }

    var component = bytes
    while component.first == 0x00, component.count > 32 {
      component.removeFirst()
    }
    guard !component.isEmpty, component.count <= 32 else {
      throw invalidES256SignatureError()
    }

    var padded = Data(repeating: 0x00, count: 32 - component.count)
    padded.append(contentsOf: component)
    return padded
  }

  private static func invalidES256SignatureError() -> BiometricCredentialKeyManagerError {
    .signingFailed("Security returned an invalid ES256 signature.")
  }

  private static func errorMessage(from error: Unmanaged<CFError>?) -> String {
    guard let error else {
      return "Unknown Security framework error."
    }
    return (error.takeRetainedValue() as Error).localizedDescription
  }
}

/// A locally generated private key and its backend-facing public key material.
package struct BiometricCredentialLocalKey: Equatable {
  package let localKeyId: String
  package let publicKeyJWK: String
  package let algorithm: BiometricCredential.Algorithm
  package let policy: BiometricCredentialPolicy

  package init(
    localKeyId: String,
    publicKeyJWK: String,
    algorithm: BiometricCredential.Algorithm = .es256,
    policy: BiometricCredentialPolicy = .biometryCurrentSet
  ) {
    self.localKeyId = localKeyId
    self.publicKeyJWK = publicKeyJWK
    self.algorithm = algorithm
    self.policy = policy
  }
}

/// A signed biometric-credential challenge payload ready to send to Clerk.
package struct BiometricCredentialKeySignature: Equatable {
  package let clientData: String
  package let signature: String
  package let algorithm: BiometricCredential.Algorithm

  package init(
    clientData: String,
    signature: String,
    algorithm: BiometricCredential.Algorithm = .es256
  ) {
    self.clientData = clientData
    self.signature = signature
    self.algorithm = algorithm
  }
}

/// Errors produced by local biometric-credential key management.
public enum BiometricCredentialKeyManagerError: Error, Equatable, LocalizedError, Sendable {
  case unsupportedPlatform
  case biometricAuthenticationUnavailable
  case biometricAuthenticationCanceled
  case biometricAuthenticationFailed
  case keyGenerationFailed(String)
  case keyNotFound
  case invalidPublicKey
  case publicKeyExportFailed(String)
  case unsupportedAlgorithm
  case signingFailed(String)
  case deletionFailed(OSStatus)

  public var errorDescription: String? {
    switch self {
    case .unsupportedPlatform:
      "Biometric sign-in is only available on supported Apple devices."
    case .biometricAuthenticationUnavailable:
      "Biometric authentication is not available or not enrolled on this device."
    case .biometricAuthenticationCanceled:
      "Biometric authentication was canceled."
    case .biometricAuthenticationFailed:
      "Biometric authentication failed."
    case let .keyGenerationFailed(message):
      "Unable to create the biometric-credential private key. \(message)"
    case .keyNotFound:
      "The biometric-credential private key was not found."
    case .invalidPublicKey:
      "The biometric-credential public key is invalid."
    case let .publicKeyExportFailed(message):
      "Unable to export the biometric-credential public key. \(message)"
    case .unsupportedAlgorithm:
      "The biometric-credential signing algorithm is not supported."
    case let .signingFailed(message):
      "Unable to sign the biometric-credential challenge. \(message)"
    case let .deletionFailed(status):
      "Unable to delete the biometric-credential private key. Security returned status \(status)."
    }
  }
}

package protocol BiometricCredentialKeyManagerProtocol: Sendable {
  @MainActor func isSupported(policy: BiometricCredentialPolicy) -> Bool
  @MainActor func createKey(policy: BiometricCredentialPolicy) throws -> BiometricCredentialLocalKey
  @MainActor func sign(
    clientData: String,
    localKeyId: String,
    localizedReason: String?
  ) throws -> BiometricCredentialKeySignature
  @MainActor func hasKey(localKeyId: String) throws -> Bool
  @MainActor func deleteKey(localKeyId: String) throws
}
