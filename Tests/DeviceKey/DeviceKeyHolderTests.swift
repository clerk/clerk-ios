@testable import ClerkKit
import CryptoKit
import Foundation
import Testing

struct DeviceKeyHolderTests {
  private let data = Data("signing input".utf8)

  @Test
  func signsWithAKeyThatVerifies() throws {
    let holder = DeviceKeyHolder(store: InMemoryDeviceKeyStore())

    let (signature, key) = try holder.withKey { key in try (key.sign(data), key) }.get()

    #expect(try publicKey(of: key).isValidSignature(
      P256.Signing.ECDSASignature(rawRepresentation: signature),
      for: data
    ))
  }

  @Test
  func loadsTheSameKeyEveryTime() throws {
    let store = InMemoryDeviceKeyStore()

    let first = try DeviceKeyHolder(store: store).withKey(\.thumbprint).get()
    let second = try DeviceKeyHolder(store: store).withKey(\.thumbprint).get()

    #expect(first == second)
  }

  @Test
  func aStoreThatCannotLoadLeavesTheKeyUnavailable() {
    let holder = DeviceKeyHolder(store: FailingDeviceKeyStore())

    #expect(holder.state().isUnavailable)
    #expect(throws: DeviceKeyError.keychain(errSecInteractionNotAllowed)) {
      try holder.withKey(\.thumbprint).get()
    }
  }

  @Test
  func aKeyTheKeychainLostIsReplacedOnce() throws {
    let store = InMemoryDeviceKeyStore()
    let holder = DeviceKeyHolder(store: store)
    let lost = try holder.withKey(\.thumbprint).get()
    try store.delete()
    var attempts = 0

    let replacement = try holder.withKey { key in
      attempts += 1
      if attempts == 1 { throw DeviceKeyError.security("The key is gone.") }
      return key.thumbprint
    }.get()

    #expect(attempts == 2)
    #expect(replacement != lost)
  }

  @Test
  func aKeyLostAgainAfterTheReplacementIsUnavailable() throws {
    let store = InMemoryDeviceKeyStore()
    let holder = DeviceKeyHolder(store: store)
    _ = holder.state()
    try store.delete()

    let result = holder.withKey { _ in
      try store.delete()
      throw DeviceKeyError.security("The key is gone.")
    }

    #expect(throws: DeviceKeyError.security("The key is gone.")) { try result.get() }
    #expect(holder.loadedState?.isUnavailable == true)
  }

  @Test
  func aFailureWhileTheKeyIsStoredKeepsTheKey() throws {
    let holder = DeviceKeyHolder(store: InMemoryDeviceKeyStore())
    let before = try holder.withKey(\.thumbprint).get()

    let result = holder.withKey { _ -> String in throw DeviceKeyError.security("busy") }

    #expect(throws: DeviceKeyError.security("busy")) { try result.get() }
    #expect(try holder.withKey(\.thumbprint).get() == before)
  }

  @Test
  func deletingTheKeyCreatesANewOneOnTheNextUse() throws {
    let holder = DeviceKeyHolder(store: InMemoryDeviceKeyStore())
    let before = try holder.withKey(\.thumbprint).get()

    try holder.deleteKey()

    #expect(try holder.withKey(\.thumbprint).get() != before)
  }

  @Test
  func secureEnclaveKeysReportTheHardwareLevelFapiAccepts() {
    #expect(DeviceKeySecurityLevel.secureEnclave.wireName == "tee")
    #expect(DeviceKeySecurityLevel.software.wireName == "software")
  }

  private func publicKey(of key: any DeviceKey) throws -> P256.Signing.PublicKey {
    let x = try #require(key.publicJwk.xCoordinate.dataFromBase64URL())
    let y = try #require(key.publicJwk.yCoordinate.dataFromBase64URL())
    return try P256.Signing.PublicKey(rawRepresentation: x + y)
  }
}

private struct FailingDeviceKeyStore: DeviceKeyStore {
  func loadOrCreate() throws -> any DeviceKey {
    throw DeviceKeyError.keychain(errSecInteractionNotAllowed)
  }

  func hasStoredKey() throws -> Bool {
    throw DeviceKeyError.keychain(errSecInteractionNotAllowed)
  }

  func delete() throws {}
}
