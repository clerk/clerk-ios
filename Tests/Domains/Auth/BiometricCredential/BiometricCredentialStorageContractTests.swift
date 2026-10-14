@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Security
import Testing

/// Pins the on-device biometric credential format that `@clerk/expo-biometrics` also reads and writes:
/// Secure Enclave keys tagged `dev.clerk.trusted_device.<localKeyId>`, the `trustedDeviceCredentials`
/// generic-password item (JSON records, millisecond dates), and the reinstall marker key.
/// A failure here means other SDKs break too, so change the format with a migration, not the expectation.
@MainActor
@Suite(.serialized)
struct BiometricCredentialStorageContractTests {
  private static let fixtureLocalKeyId = "tdlk_0123456789abcdef0123456789abcdef"

  private static let fixtureRecords: [BiometricCredentialLocalRecord] = [
    BiometricCredentialLocalRecord(
      id: "tdc_contract_current_set",
      localKeyId: "tdlk_0123456789abcdef0123456789abcdef",
      userID: "user_contract_1",
      appIdentifier: "com.clerk.example",
      identifierHint: "user@example.com",
      policy: .biometryCurrentSet,
      createdAt: Date(timeIntervalSince1970: 1_714_000_000.5),
      updatedAt: Date(timeIntervalSince1970: 1_714_000_001.5)
    ),
    BiometricCredentialLocalRecord(
      id: "tdc_contract_any",
      localKeyId: "tdlk_fedcba9876543210fedcba9876543210",
      userID: "user_contract_2",
      appIdentifier: "com.clerk.example",
      policy: .biometryAny,
      createdAt: Date(timeIntervalSince1970: 1_714_000_002),
      updatedAt: Date(timeIntervalSince1970: 1_714_000_003)
    ),
    BiometricCredentialLocalRecord(
      id: "tdc_contract_passcode",
      localKeyId: "tdlk_00000000000000000000000000000000",
      userID: "user_contract_1",
      appIdentifier: "com.clerk.other",
      identifierHint: "+15555550100",
      policy: .biometryOrDevicePasscode,
      createdAt: Date(timeIntervalSince1970: 1_714_000_004),
      updatedAt: Date(timeIntervalSince1970: 1_714_000_004)
    ),
  ]

  // MARK: - Secure Enclave key

  @Test
  func privateKeyQueryUsesContractApplicationTagWithoutAccessGroup() {
    let query = BiometricCredentialKeyManager.privateKeyQuery(localKeyId: Self.fixtureLocalKeyId)

    #expect(query[kSecClass as String] as? String == kSecClassKey as String)
    #expect(query[kSecAttrKeyClass as String] as? String == kSecAttrKeyClassPrivate as String)
    #expect(query[kSecAttrKeyType as String] as? String == kSecAttrKeyTypeECSECPrimeRandom as String)
    #expect(
      query[kSecAttrApplicationTag as String] as? Data ==
        Data("dev.clerk.trusted_device.tdlk_0123456789abcdef0123456789abcdef".utf8)
    )
    #expect(query[kSecAttrAccessGroup as String] == nil)
    #expect(query[kSecAttrLabel as String] == nil)
    #expect(query[kSecAttrApplicationLabel as String] == nil)
  }

  @Test
  func privateKeyAttributesMatchContract() throws {
    let attributes = try BiometricCredentialKeyManager.makePrivateKeyAttributes(
      localKeyId: Self.fixtureLocalKeyId,
      accessControl: BiometricCredentialKeyManager.makeAccessControl(policy: .biometryCurrentSet)
    )

    #expect(attributes[kSecAttrKeyType as String] as? String == kSecAttrKeyTypeECSECPrimeRandom as String)
    #expect(attributes[kSecAttrKeySizeInBits as String] as? Int == 256)
    #expect(attributes[kSecAttrTokenID as String] as? String == kSecAttrTokenIDSecureEnclave as String)
    #expect(attributes[kSecAttrAccessGroup as String] == nil)

    let privateKeyAttributes = try #require(attributes[kSecPrivateKeyAttrs as String] as? [String: Any])
    #expect(privateKeyAttributes[kSecAttrIsPermanent as String] as? Bool == true)
    #expect(
      privateKeyAttributes[kSecAttrApplicationTag as String] as? Data ==
        Data("dev.clerk.trusted_device.tdlk_0123456789abcdef0123456789abcdef".utf8)
    )
    #expect(privateKeyAttributes[kSecAttrAccessControl as String] != nil)
    #expect(privateKeyAttributes[kSecAttrAccessGroup as String] == nil)
  }

  @Test
  func policyRawValuesAndAccessControlFlagsMatchContract() {
    #expect(BiometricCredentialPolicy.biometryCurrentSet.rawValue == "biometry_current_set")
    #expect(BiometricCredentialPolicy.biometryAny.rawValue == "biometry_any")
    #expect(BiometricCredentialPolicy.biometryOrDevicePasscode.rawValue == "biometry_or_device_passcode")

    #expect(BiometricCredentialKeyManager.accessControlFlags(for: .biometryCurrentSet) == [
      .privateKeyUsage,
      .biometryCurrentSet,
    ])
    #expect(BiometricCredentialKeyManager.accessControlFlags(for: .biometryAny) == [
      .privateKeyUsage,
      .biometryAny,
    ])
    #expect(BiometricCredentialKeyManager.accessControlFlags(for: .biometryOrDevicePasscode) == [
      .privateKeyUsage,
      .userPresence,
    ])
  }

  // MARK: - Signing and public key

  @Test
  func publicKeyJWKMatchesContractFormat() throws {
    var representation = Data([0x04])
    representation.append(Data(repeating: 0x01, count: 32))
    representation.append(Data(repeating: 0x02, count: 32))

    let jwk = try BiometricCredentialKeyManager.publicKeyJWK(fromX963Representation: representation)

    #expect(
      jwk == #"{"kty":"EC","crv":"P-256","x":"AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE","y":"AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI","alg":"ES256"}"#
    )
  }

  @Test
  func signatureIsRawRAndSEncodedAsUnpaddedBase64URL() throws {
    let rComponent: [UInt8] = [0x00, 0x80] + Array(repeating: 0xAA, count: 31)
    let sComponent: [UInt8] = Array(repeating: 0x11, count: 31)
    let der = Data(
      [0x30, 0x44, 0x02, UInt8(rComponent.count)] + rComponent + [0x02, UInt8(sComponent.count)] + sComponent
    )

    let raw = try BiometricCredentialKeyManager.rawES256Signature(fromDEREncoded: der)

    #expect(raw.count == 64)
    #expect(
      BiometricCredentialKeyManager.base64URLEncodedString(raw) ==
        "gKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqoAEREREREREREREREREREREREREREREREREREREREREQ"
    )
  }

  // MARK: - Metadata Keychain item

  @Test
  func metadataKeychainAccountMatchesContract() throws {
    #expect(ClerkKeychainKey.biometricCredentials.rawValue == "trustedDeviceCredentials")

    let keychain = InMemoryKeychain()
    try BiometricCredentialLocalStore(keychain: keychain).save(Self.fixtureRecords[0])

    #expect(try keychain.hasItem(forKey: "trustedDeviceCredentials"))
  }

  @Test
  func metadataKeychainItemUsesGenericPasswordAttributes() throws {
    let addQueries = LockIsolated<[[String: String]]>([])
    let client = SystemKeychain.SecItemClient(
      add: { query, _ in
        let attributes = query as NSDictionary
        let captured: [String: String] = [
          "class": attributes[kSecClass as String] as? String ?? "",
          "service": attributes[kSecAttrService as String] as? String ?? "",
          "account": attributes[kSecAttrAccount as String] as? String ?? "",
          "accessible": attributes[kSecAttrAccessible as String] as? String ?? "",
          "accessGroup": attributes[kSecAttrAccessGroup as String] as? String ?? "<none>",
        ]
        addQueries.withValue { $0.append(captured) }
        return errSecSuccess
      },
      update: { _, _ in errSecSuccess },
      copyMatching: { _, _ in errSecItemNotFound },
      delete: { _ in errSecSuccess }
    )
    let keychain = SystemKeychain(service: "com.clerk.example", secItemClient: client)

    try BiometricCredentialLocalStore(keychain: keychain).save(Self.fixtureRecords[0])

    #expect(addQueries.value == [[
      "class": kSecClassGenericPassword as String,
      "service": "com.clerk.example",
      "account": "trustedDeviceCredentials",
      "accessible": kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String,
      "accessGroup": "<none>",
    ]])
  }

  @Test
  func v1FixtureDecodesToExpectedRecords() throws {
    let keychain = InMemoryKeychain()
    try keychain.set(Self.fixtureData(), forKey: "trustedDeviceCredentials")
    let store = BiometricCredentialLocalStore(keychain: keychain)

    #expect(try store.all() == Self.fixtureRecords)
    #expect(try store.all(appIdentifier: "com.clerk.example") == Array(Self.fixtureRecords.prefix(2)))
    #expect(try store.credential(id: "tdc_contract_passcode") == Self.fixtureRecords[2])
  }

  @Test
  func expectedRecordsEncodeToV1Fixture() throws {
    let keychain = InMemoryKeychain()
    let store = BiometricCredentialLocalStore(keychain: keychain)

    for record in Self.fixtureRecords {
      try store.save(record)
    }

    let stored = try #require(try keychain.data(forKey: "trustedDeviceCredentials"))
    let storedJSON = try JSONSerialization.jsonObject(with: stored) as? NSArray
    let fixtureJSON = try JSONSerialization.jsonObject(with: Self.fixtureData()) as? NSArray
    #expect(storedJSON != nil)
    #expect(storedJSON == fixtureJSON)
  }

  @Test
  func recordFieldNamesMatchContract() throws {
    let keychain = InMemoryKeychain()
    let store = BiometricCredentialLocalStore(keychain: keychain)
    try store.save(Self.fixtureRecords[0])
    try store.save(Self.fixtureRecords[1])

    let stored = try #require(try keychain.data(forKey: "trustedDeviceCredentials"))
    let records = try #require(try JSONSerialization.jsonObject(with: stored) as? [[String: Any]])

    #expect(records.count == 2)
    #expect(Set(records[0].keys) == [
      "id", "localKeyId", "userId", "appIdentifier", "identifierHint", "policy", "createdAt", "updatedAt",
    ])
    #expect(Set(records[1].keys) == [
      "id", "localKeyId", "userId", "appIdentifier", "policy", "createdAt", "updatedAt",
    ])
    #expect((records[0]["createdAt"] as? NSNumber)?.int64Value == 1_714_000_000_500)
  }

  @Test
  func readersIgnoreUnknownFieldsAndNormalizeIdentifierHints() throws {
    let json = """
    [{"id":"tdc_future","localKeyId":"tdlk_future","userId":"user_1","appIdentifier":"com.clerk.example",\
    "identifierHint":"  User@Example.COM ","policy":"biometry_any","createdAt":1714000000000,\
    "updatedAt":1714000000000,"futureField":{"nested":true}}]
    """
    let keychain = InMemoryKeychain()
    try keychain.set(Data(json.utf8), forKey: "trustedDeviceCredentials")
    let store = BiometricCredentialLocalStore(keychain: keychain)

    let record = try #require(try store.all(appIdentifier: "com.clerk.example").first)
    #expect(record.id == "tdc_future")
    #expect(record.identifierHint == "user@example.com")
    #expect(record.matches(identifierHint: " USER@example.com\n"))
  }

  @Test
  func saveKeepsUnknownFieldsOnOtherRecords() throws {
    let json = """
    [{"id":"tdc_other","localKeyId":"tdlk_other","userId":"user_1","appIdentifier":"com.clerk.other",\
    "policy":"biometry_any","createdAt":1714000000000,"updatedAt":1714000000000,"futureField":"kept"}]
    """
    let keychain = InMemoryKeychain()
    try keychain.set(Data(json.utf8), forKey: "trustedDeviceCredentials")

    try BiometricCredentialLocalStore(keychain: keychain).save(Self.fixtureRecords[0])

    let stored = try #require(try keychain.data(forKey: "trustedDeviceCredentials"))
    let records = try #require(try JSONSerialization.jsonObject(with: stored) as? [[String: Any]])
    #expect(records.map { $0["id"] as? String } == ["tdc_other", "tdc_contract_current_set"])
    #expect(records[0]["futureField"] as? String == "kept")
  }

  // MARK: - Reinstall marker

  @Test
  func installationMarkerKeyMatchesContractFormat() {
    #expect(
      Clerk.biometricCredentialInstallationMarkerKey(
        for: .init(service: "com.clerk.example", accessGroup: nil),
        appIdentifier: "com.clerk.example"
      ) == "com.clerk.trusted-device-installation-marker.s17:com.clerk.example.n.s17:com.clerk.example"
    )
    #expect(
      Clerk.biometricCredentialInstallationMarkerKey(
        for: .init(service: "com.clerk.é", accessGroup: "TEAMID.com.clerk.shared"),
        appIdentifier: "com.clerk.example"
      ) == "com.clerk.trusted-device-installation-marker.s12:com.clerk.é.s23:TEAMID.com.clerk.shared.s17:com.clerk.example"
    )
    #expect(
      Clerk.biometricCredentialInstallationMarkerKey(
        for: .init(service: "com.clerk.example", accessGroup: ""),
        appIdentifier: "com.clerk.example"
      ) == "com.clerk.trusted-device-installation-marker.s17:com.clerk.example.s0:.s17:com.clerk.example"
    )
  }

  private static func fixtureData() throws -> Data {
    let url = try #require(Bundle.module.url(forResource: "BiometricCredentialStorageContractV1", withExtension: "json"))
    return try Data(contentsOf: url)
  }
}
