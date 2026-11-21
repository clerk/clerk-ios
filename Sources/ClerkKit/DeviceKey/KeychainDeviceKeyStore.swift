//
//  KeychainDeviceKeyStore.swift
//  Clerk
//

import CryptoKit
import Foundation
import Security

struct KeychainDeviceKeyStore: DeviceKeyStore {
  static let applicationTag = Data("com.clerk.device_key.v1".utf8)

  let usesSecureEnclave: Bool

  init(usesSecureEnclave: Bool = SecureEnclave.isAvailable) {
    self.usesSecureEnclave = usesSecureEnclave
  }

  func loadOrCreate() throws -> any DeviceKey {
    if let stored = try storedKey() {
      return stored
    }
    return try createKey()
  }

  func hasStoredKey() throws -> Bool {
    let status = SecItemCopyMatching(Self.privateKeyQuery() as CFDictionary, nil)
    switch status {
    case errSecSuccess:
      return true
    case errSecItemNotFound:
      return false
    default:
      throw DeviceKeyError.keychain(status)
    }
  }

  func delete() throws {
    let status = SecItemDelete(Self.privateKeyQuery() as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw DeviceKeyError.keychain(status)
    }
  }

  private func storedKey() throws -> SecKeyDeviceKey? {
    var query = Self.privateKeyQuery()
    query[kSecReturnRef as String] = true
    query[kSecReturnAttributes as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    switch status {
    case errSecSuccess:
      break
    case errSecItemNotFound:
      return nil
    default:
      throw DeviceKeyError.keychain(status)
    }

    guard let attributes = result as? [String: Any],
          let reference = attributes[kSecValueRef as String],
          CFGetTypeID(reference as CFTypeRef) == SecKeyGetTypeID()
    else {
      throw DeviceKeyError.security("The keychain returned a device key item without a key.")
    }
    let tokenID = attributes[kSecAttrTokenID as String] as? String
    return try SecKeyDeviceKey(
      privateKey: reference as! SecKey, // swiftlint:disable:this force_cast
      securityLevel: tokenID == (kSecAttrTokenIDSecureEnclave as String) ? .secureEnclave : .software
    )
  }

  private func createKey() throws -> SecKeyDeviceKey {
    var privateKeyAttributes: [String: Any] = [
      kSecAttrIsPermanent as String: true,
      kSecAttrApplicationTag as String: Self.applicationTag,
    ]
    var attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
    ]

    if usesSecureEnclave {
      var error: Unmanaged<CFError>?
      guard let accessControl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        .privateKeyUsage,
        &error
      ) else {
        throw DeviceKeyError.security(Self.message(from: error))
      }
      attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
      privateKeyAttributes[kSecAttrAccessControl as String] = accessControl
    } else {
      privateKeyAttributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    }
    attributes[kSecPrivateKeyAttrs as String] = privateKeyAttributes
    #if os(macOS)
    attributes[kSecUseDataProtectionKeychain as String] = kCFBooleanTrue
    #endif

    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      throw DeviceKeyError.security(Self.message(from: error))
    }
    return try SecKeyDeviceKey(
      privateKey: privateKey,
      securityLevel: usesSecureEnclave ? .secureEnclave : .software
    )
  }

  private static func privateKeyQuery() -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrApplicationTag as String: applicationTag,
    ]
    #if os(macOS)
    query[kSecUseDataProtectionKeychain as String] = kCFBooleanTrue
    #endif
    return query
  }

  fileprivate static func message(from error: Unmanaged<CFError>?) -> String {
    guard let error else { return "Unknown Security framework error." }
    return (error.takeRetainedValue() as Error).localizedDescription
  }
}

private struct SecKeyDeviceKey: DeviceKey, @unchecked Sendable {
  let privateKey: SecKey
  let publicJwk: Es256PublicJwk
  let securityLevel: DeviceKeySecurityLevel

  init(privateKey: SecKey, securityLevel: DeviceKeySecurityLevel) throws {
    guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
      throw DeviceKeyError.security("Unable to copy the device public key.")
    }
    var error: Unmanaged<CFError>?
    guard let representation = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
      throw DeviceKeyError.security(KeychainDeviceKeyStore.message(from: error))
    }
    self.privateKey = privateKey
    publicJwk = try Es256.publicJwk(fromX963Representation: representation)
    self.securityLevel = securityLevel
  }

  func sign(_ data: Data) throws -> Data {
    var error: Unmanaged<CFError>?
    guard let signature = SecKeyCreateSignature(
      privateKey,
      .ecdsaSignatureMessageX962SHA256,
      data as CFData,
      &error
    ) as Data? else {
      throw DeviceKeyError.security(KeychainDeviceKeyStore.message(from: error))
    }
    return try Es256.rawSignature(fromDER: signature)
  }
}
