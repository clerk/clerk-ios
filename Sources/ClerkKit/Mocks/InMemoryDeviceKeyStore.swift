//
//  InMemoryDeviceKeyStore.swift
//  Clerk
//

import CryptoKit
import Foundation

final class InMemoryDeviceKeyStore: DeviceKeyStore, @unchecked Sendable {
  private let lock = NSLock()
  private var stored: InMemoryDeviceKey?

  func loadOrCreate() throws -> any DeviceKey {
    lock.withLock {
      if let stored { return stored }
      let created = InMemoryDeviceKey(privateKey: P256.Signing.PrivateKey())
      stored = created
      return created
    }
  }

  func hasStoredKey() throws -> Bool {
    lock.withLock { stored != nil }
  }

  func delete() throws {
    lock.withLock { stored = nil }
  }
}

struct InMemoryDeviceKey: DeviceKey {
  let privateKey: P256.Signing.PrivateKey

  var publicJwk: Es256PublicJwk {
    // swiftlint:disable:next force_try
    try! Es256.publicJwk(fromX963Representation: privateKey.publicKey.x963Representation)
  }

  var securityLevel: DeviceKeySecurityLevel {
    .software
  }

  func sign(_ data: Data) throws -> Data {
    try privateKey.signature(for: data).rawRepresentation
  }
}
