@testable import ClerkKit
import CryptoKit
import Foundation
import Security
import Testing

struct AppleCredentialStorageTests {
  private let application = "com.clerk.storage-contract"
  private let key = "pk_test_storage_contract"
  private let origin = URL(string: "https://storage-contract.clerk.accounts.dev")!
  private let legacyService = "legacy.clerk.service"
  private var fingerprint: String {
    SHA256.hash(data: Data("clerk.shared-session-sync.v2\u{1F}\(origin.absoluteString)\u{1F}\(key)".utf8)).map { String(format: "%02x", $0) }.joined()
  }

  private var legacyClient: JSONValue {
    .object(["id": .string("client_fixture"), "sessions": .array([]), "updated_at": .number(1_700_000_000_000)])
  }

  private var acceptedIdentity: JSONValue {
    .object(["state": .string("present"), "device_token": .string("accepted"), "client": legacyClient])
  }

  private func storage(_ probe: SecurityItemProbe, key: String? = nil, application: String? = nil, legacy: LegacyKeychainConfiguration = .init(), purpose: KeychainCredentialStorage.Purpose = .client) -> KeychainCredentialStorage {
    KeychainCredentialStorage(publishableKey: key ?? self.key, frontendAPI: origin, applicationIdentifier: application ?? self.application, legacy: legacy, purpose: purpose, items: probe.client)
  }

  @Test func writesUpdatesAndClearsSurviveReconstructionWithoutReimportingLegacy() async throws {
    let probe = SecurityItemProbe()
    let legacy = LegacyKeychainConfiguration(service: legacyService, publishableKey: key)
    probe.seed(service: legacyService, account: "clerkDeviceToken", value: Data("legacy".utf8))
    let first = storage(probe, legacy: legacy)
    #expect(try await first.read() == "legacy")
    try await first.write("updated")
    #expect(try await storage(probe, legacy: legacy).read() == "updated")
    try await first.remove()
    try await first.remove()
    #expect(try await storage(probe, legacy: legacy).read() == nil)
    #expect(probe.value(service: legacyService, account: "clerkDeviceToken") == Data("legacy".utf8))
  }

  @Test func applicationKeyAndPurposeKeepCredentialsSeparate() async throws {
    let probe = SecurityItemProbe()
    try await storage(probe).write("current")
    #expect(try await storage(probe).read() == "current")
    #expect(try await storage(probe, key: "pk_test_other").read() == nil)
    #expect(try await storage(probe, application: "com.clerk.other").read() == nil)
    #expect(try await storage(probe, purpose: .magicLink).read() == nil)
    #expect(try await storage(probe, purpose: .biometricCredentials).read() == nil)
    #expect(try await storage(probe, purpose: .biometricCleanup).read() == nil)
  }

  @Test func unscopedLegacyCredentialsRequireAnExplicitMatchingKey() async throws {
    for legacyKey in [String?.none, "pk_test_other", key] {
      let probe = SecurityItemProbe()
      probe.seed(service: legacyService, account: "clerkDeviceToken", value: Data("legacy".utf8))
      let result = try await storage(probe, legacy: .init(service: legacyService, publishableKey: legacyKey)).read()
      #expect(result == (legacyKey == key ? "legacy" : nil))
    }
  }

  @Test func legacyBiometricMetadataRequiresMatchingInstanceAndSurvivesReconstruction() async throws {
    // BiometricCredentialLocalStore uses its own camelCase/millisecond encoder,
    // not the general Clerk snake_case encoder (baseline 02f98f89).
    let raw = #"[{"id":"td_legacy","localKeyId":"tdlk_legacy","userId":"user_legacy","appIdentifier":"com.clerk.storage-contract","policy":"biometry_current_set","createdAt":1700000000000,"updatedAt":1700000000001}]"#
    for legacyKey in [String?.none, "pk_test_other", key] {
      let probe = SecurityItemProbe()
      probe.seed(service: legacyService, account: "trustedDeviceCredentials", value: Data(raw.utf8))
      let legacy = LegacyKeychainConfiguration(service: legacyService, publishableKey: legacyKey)
      let current = storage(probe, legacy: legacy, purpose: .biometricCredentials)
      #expect(try await current.read() == (legacyKey == key ? raw : nil))
      #expect(try await storage(probe, legacy: legacy, purpose: .biometricCredentials).read() == (legacyKey == key ? raw : nil))
      try await current.remove()
      #expect(try await storage(probe, legacy: legacy, purpose: .biometricCredentials).read() == nil)
      #expect(probe.value(service: legacyService, account: "trustedDeviceCredentials") == Data(raw.utf8))
    }
  }

  @Test func newRecordReadErrorsDoNotImportAnOlderCredential() async throws {
    let probe = SecurityItemProbe()
    probe.seed(service: legacyService, account: "clerkDeviceToken", value: Data("old".utf8))
    let current = storage(probe, legacy: .init(service: legacyService, publishableKey: key))
    try await current.write("current")
    probe.readFailureForNewRecords = errSecInteractionNotAllowed
    do {
      _ = try await current.read()
      Issue.record("Expected the current credential's read failure")
    } catch let error as CoreError {
      #expect(error.code == "secure_storage_read_failed")
      #expect(error.details == .object(["osStatus": .number(Double(errSecInteractionNotAllowed))]))
    }
    #expect(probe.readCount(service: legacyService, account: "clerkDeviceToken") == 0)
    probe.readFailureForNewRecords = nil
    #expect(try await current.read() == "current")
  }

  @Test func failedMigrationWriteIsReportedAndLeavesLegacyDataAvailableForRetry() async throws {
    let probe = SecurityItemProbe()
    probe.seed(service: legacyService, account: "clerkDeviceToken", value: Data("legacy".utf8))
    probe.writeFailure = errSecNotAvailable
    let current = storage(probe, legacy: .init(service: legacyService, publishableKey: key))
    do {
      _ = try await current.read()
      Issue.record("Expected failed durable migration to be reported")
    } catch let error as CoreError { #expect(error.code == "secure_storage_write_failed") }
    #expect(probe.value(service: legacyService, account: "clerkDeviceToken") == Data("legacy".utf8))
    probe.writeFailure = nil
    #expect(try await current.read() == "legacy")
  }

  @Test func failedClearDoesNotReportSuccessAndCanBeRetried() async throws {
    let probe = SecurityItemProbe()
    let current = storage(probe)
    try await current.write("current")
    probe.writeFailure = errSecNotAvailable
    do {
      try await current.remove()
      Issue.record("Expected a failed durable clear to be reported")
    } catch let error as CoreError { #expect(error.code == "secure_storage_write_failed") }
    probe.writeFailure = nil
    try await current.remove()
    #expect(try await storage(probe).read() == nil)
  }

  @Test(arguments: ["same", "different", "cleared"])
  func pendingIdentityPublicationCannotRestoreAnObsoleteCredential(pending: String) async throws {
    let probe = SecurityItemProbe()
    let record: JSONValue = .object([
      "schema_version": .number(1),
      "accepted_identity": acceptedIdentity,
      "pending_publication": .object([
        "id": .string("63BDAF4D-0458-4FA6-A42D-4540CC511C91"),
        "origin_owner_identifier": .string(application), "generation": .number(1),
        "state": .string(pending == "cleared" ? "cleared" : "present"),
        "device_token": .string(pending == "same" ? "accepted" : "other"),
        "client": pending == "cleared" ? .null : legacyClient,
      ]),
    ])
    try probe.seed(service: "\(application).clerk.identity.v2.\(fingerprint)", account: "clerkSharedSessionLocalIdentityV2", value: JSONEncoder().encode(record))
    probe.seed(service: legacyService, account: "clerkDeviceToken", value: Data("unscoped".utf8))
    let current = storage(probe, legacy: .init(service: legacyService, publishableKey: key))
    #expect(try await current.read() == (pending == "same" ? "accepted" : nil))
    #expect(probe.readCount(service: legacyService, account: "clerkDeviceToken") == 0)
  }

  @Test(arguments: [false, true])
  func legacyIdentityUsesThePreviousMajorsSnakeCaseStorageFormat(versioned: Bool) async throws {
    let probe = SecurityItemProbe()
    let record: JSONValue = versioned ? .object(["schema_version": .number(1), "accepted_identity": acceptedIdentity]) : acceptedIdentity
    try probe.seed(service: "\(application).clerk.identity.v2.\(fingerprint)", account: "clerkSharedSessionLocalIdentityV2", value: JSONEncoder().encode(record))
    #expect(try await storage(probe).read() == "accepted")
  }

  @Test(arguments: [false, true])
  func interruptedLegacyClearPreventsOnlyItsInstancesCredentialImport(sameInstance: Bool) async throws {
    let probe = SecurityItemProbe()
    let record: JSONValue = .object(["schema_version": .number(1), "accepted_identity": acceptedIdentity])
    try probe.seed(service: "\(application).clerk.identity.v2.\(fingerprint)", account: "clerkSharedSessionLocalIdentityV2", value: JSONEncoder().encode(record))
    let pendingFingerprint = sameInstance ? fingerprint : "other-instance-fingerprint"
    let intent: JSONValue = .object([
      "schema_version": .number(1), "owner_identifier": .string(application),
      "instance_fingerprint": .string(pendingFingerprint),
      "local_identity_service": .string("\(application).clerk.identity.v2.\(pendingFingerprint)"),
      "slot_service": .string("legacy.shared"), "slot_access_group": .string("legacy.group"), "slot_account": .string("legacy.owner"),
    ])
    let bytes = try JSONEncoder().encode(intent)
    probe.seed(service: "\(application).clerk.shared-session-clear-recovery.v1", account: "clerkSharedSessionOwnerSlotClearIntentV1", value: bytes)
    #expect(try await storage(probe).read() == (sameInstance ? nil : "accepted"))
    #expect(try await storage(probe).read() == (sameInstance ? nil : "accepted"))
    #expect(probe.value(service: "\(application).clerk.shared-session-clear-recovery.v1", account: "clerkSharedSessionOwnerSlotClearIntentV1") == bytes)
  }

  @Test(arguments: ["{invalid}", "{}"])
  func malformedClearIntentsCannotBeIgnoredToImportCredentials(json: String) async throws {
    let probe = SecurityItemProbe()
    probe.seed(service: legacyService, account: "clerkDeviceToken", value: Data("old".utf8))
    probe.seed(service: "\(application).clerk.shared-session-clear-recovery.v1", account: "clerkSharedSessionOwnerSlotClearIntentV1", value: Data(json.utf8))
    await #expect(throws: (any Error).self) {
      try await storage(probe, legacy: .init(service: legacyService, publishableKey: key)).read()
    }
    #expect(probe.readCount(service: legacyService, account: "clerkDeviceToken") == 0)
  }

  #if os(macOS)
  @Test func macOSPrefersTheLegacySDKsDataProtectionBackend() async throws {
    let probe = SecurityItemProbe()
    probe.seed(service: legacyService, account: "clerkDeviceToken", accessGroup: "group.example", dataProtection: true, value: Data("newer".utf8))
    probe.seed(service: legacyService, account: "clerkDeviceToken", accessGroup: "group.example", value: Data("older".utf8))
    let current = storage(probe, legacy: .init(service: legacyService, accessGroup: "  group.example\n", publishableKey: " \(key)\n"))
    #expect(try await current.read() == "newer")
    #expect(probe.readCount(service: legacyService, account: "clerkDeviceToken", accessGroup: "group.example") == 0)
  }

  @Test func macOSFallsBackOnlyWhenTheDataProtectionItemIsMissing() async throws {
    let probe = SecurityItemProbe()
    probe.seed(service: legacyService, account: "clerkDeviceToken", accessGroup: "group.example", value: Data("legacy".utf8))
    let current = storage(probe, legacy: .init(service: legacyService, accessGroup: "group.example", publishableKey: key))
    #expect(try await current.read() == "legacy")
    #expect(probe.readCount(service: legacyService, account: "clerkDeviceToken", accessGroup: "group.example", dataProtection: true) == 1)
  }

  @Test func macOSDataProtectionFailureDoesNotRestoreTheFallbackCredential() async throws {
    let probe = SecurityItemProbe()
    probe.seed(service: legacyService, account: "clerkDeviceToken", accessGroup: "group.example", value: Data("older".utf8))
    probe.dataProtectionReadFailure = errSecMissingEntitlement
    let current = storage(probe, legacy: .init(service: legacyService, accessGroup: "group.example", publishableKey: key))
    do {
      _ = try await current.read()
      Issue.record("Expected entitlement failure, not an older credential")
    } catch let error as CoreError {
      #expect(error.code == "secure_storage_read_failed")
      #expect(error.message.contains("Keychain Sharing"))
      #expect(error.message.contains("accessGroup"))
      #expect(error.details == .object(["osStatus": .number(Double(errSecMissingEntitlement))]))
    }
    #expect(probe.readCount(service: legacyService, account: "clerkDeviceToken", accessGroup: "group.example") == 0)
  }
  #endif
}

/// OS-call boundary only: tests use the public storage operations. All mutable
/// probe state is locked because several actor-owned stores can share this client.
private final class SecurityItemProbe: @unchecked Sendable {
  private struct Key: Hashable {
    let service: String
    let account: String
    let accessGroup: String?
    let dataProtection: Bool
  }

  private struct State {
    var records: [Key: Data] = [:]
    var reads: [Key] = []
    var writeFailure: OSStatus?
    var readFailureForNewRecords: OSStatus?
    var dataProtectionReadFailure: OSStatus?
  }

  private let lock = NSLock()
  private var state = State()
  private func locked<T>(_ body: (inout State) -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body(&state)
  }

  var writeFailure: OSStatus? {
    get { locked { $0.writeFailure } }
    set { locked { $0.writeFailure = newValue } }
  }

  var readFailureForNewRecords: OSStatus? {
    get { locked { $0.readFailureForNewRecords } }
    set { locked { $0.readFailureForNewRecords = newValue } }
  }

  var dataProtectionReadFailure: OSStatus? {
    get { locked { $0.dataProtectionReadFailure } }
    set { locked { $0.dataProtectionReadFailure = newValue } }
  }

  func seed(service: String, account: String, accessGroup: String? = nil, dataProtection: Bool = false, value: Data) {
    locked { $0.records[Key(service: service, account: account, accessGroup: accessGroup, dataProtection: dataProtection)] = value }
  }

  func value(service: String, account: String, accessGroup: String? = nil, dataProtection: Bool = false) -> Data? {
    locked { $0.records[Key(service: service, account: account, accessGroup: accessGroup, dataProtection: dataProtection)] }
  }

  func readCount(service: String, account: String, accessGroup: String? = nil, dataProtection: Bool = false) -> Int {
    let key = Key(service: service, account: account, accessGroup: accessGroup, dataProtection: dataProtection)
    return locked { $0.reads.filter { $0 == key }.count }
  }

  private func key(_ query: CFDictionary) -> Key {
    let values = query as NSDictionary
    return Key(service: values[kSecAttrService] as? String ?? "", account: values[kSecAttrAccount] as? String ?? "", accessGroup: values[kSecAttrAccessGroup] as? String, dataProtection: values[kSecUseDataProtectionKeychain] as? Bool == true)
  }

  var client: SecurityItemClient {
    SecurityItemClient(add: { query, _ in
      let key = self.key(query)
      return self.locked {
        if let failure = $0.writeFailure { return failure }
        if $0.records[key] != nil { return errSecDuplicateItem }
        guard let data = (query as NSDictionary)[kSecValueData] as? Data else { return errSecParam }
        $0.records[key] = data
        return errSecSuccess
      }
    }, update: { query, attributes in
      let key = self.key(query)
      return self.locked {
        if let failure = $0.writeFailure { return failure }
        guard $0.records[key] != nil else { return errSecItemNotFound }
        guard let data = (attributes as NSDictionary)[kSecValueData] as? Data else { return errSecParam }
        $0.records[key] = data
        return errSecSuccess
      }
    }, copyMatching: { query, result in
      let key = self.key(query)
      return self.locked {
        $0.reads.append(key)
        if key.service.contains(".clerk.core.v2."), let failure = $0.readFailureForNewRecords { return failure }
        if key.dataProtection, let failure = $0.dataProtectionReadFailure { return failure }
        guard let data = $0.records[key] else { return errSecItemNotFound }
        result?.pointee = data as CFData
        return errSecSuccess
      }
    })
  }
}
