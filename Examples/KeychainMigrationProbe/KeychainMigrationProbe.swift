import ClerkKit
import CryptoKit
import Foundation
import Security
import SwiftUI

@main struct KeychainMigrationProbeApp: App {
  @State private var result = "Preparing isolated Keychain records…"
  @State private var didRun = false
  var body: some Scene {
    WindowGroup {
      ScrollView {
        Text(result).font(.system(.caption, design: .monospaced)).textSelection(.enabled).padding()
      }
      .task {
        guard !didRun else { return }
        didRun = true
        do {
          let report = try await KeychainMigrationProbe.run()
          let encoder = JSONEncoder()
          encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
          let data = try encoder.encode(report)
          let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
          try data.write(to: directory.appendingPathComponent("keychain-migration-probe.json"), options: .atomic)
          result = String(decoding: data, as: UTF8.self)
          print("KEYCHAIN_MIGRATION_PROBE_REPORT " + String(decoding: data, as: UTF8.self))
        } catch {
          result = "Probe failed: \(error)"
          print(result)
        }
      }
    }
  }
}

private enum KeychainMigrationProbe {
  struct Item: Codable {
    let service: String
    let account: String
    let group: String
    let value: String
  }

  struct Observation: Codable {
    let name: String
    let purpose: String
    let omittedGroup: [Item]
    let explicitPrivate: [Item]
    let explicitShared: [Item]
    let previousBundle: [Item]
    let acceptedLocalIdentity: [Item]
    let migrated: String?
    let reconstructed: String?
    let afterClear: String?
  }

  struct Report: Codable {
    let schemaVersion: Int
    let runIdentifier: String
    let operatingSystem: String
    let privateGroup: String
    let sharedGroup: String
    let defaultInsertion: [Item]
    let observations: [Observation]
  }

  struct ProbeError: Error, CustomStringConvertible {
    let description: String
  }

  static func hash(_ string: String) -> String {
    SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  static func query(service: String, account: String, group: String? = nil) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    if let group { query[kSecAttrAccessGroup as String] = group }
    return query
  }

  static func insert(_ value: String, service: String, account: String, group: String? = nil) throws {
    var query = query(service: service, account: account, group: group)
    query[kSecValueData as String] = Data(value.utf8)
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else { throw ProbeError(description: "Seed failed with OSStatus \(status)") }
  }

  static func lookup(service: String, account: String, group: String? = nil) throws -> [Item] {
    var query = query(service: service, account: account, group: group)
    query[kSecReturnAttributes as String] = true
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitAll
    var value: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &value)
    if status == errSecItemNotFound { return [] }
    guard status == errSecSuccess, let records = value as? [[String: Any]] else {
      throw ProbeError(description: "Attribute lookup failed with OSStatus \(status)")
    }
    return try records.map { record in
      guard let service = record[kSecAttrService as String] as? String,
            let account = record[kSecAttrAccount as String] as? String,
            let group = record[kSecAttrAccessGroup as String] as? String,
            let data = record[kSecValueData as String] as? Data,
            let value = String(data: data, encoding: .utf8)
      else { throw ProbeError(description: "Attribute lookup returned an unexpected shape") }
      return Item(service: service, account: account, group: group, value: value)
    }
  }

  static func run() async throws -> Report {
    guard let privateGroup = Bundle.main.object(forInfoDictionaryKey: "ProbePrivateGroup") as? String,
          let sharedGroup = Bundle.main.object(forInfoDictionaryKey: "ProbeSharedGroup") as? String,
          !privateGroup.contains("$("), !sharedGroup.contains("$("), privateGroup != sharedGroup
    else { throw ProbeError(description: "Build must supply distinct resolved private/shared access groups") }
    let runID = UUID().uuidString
    let prefix = "com.clerk.nativecore.keychain-probe.\(runID)"
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    guard let origin = URL(string: "https://native-core.clerk.accounts.dev") else {
      throw ProbeError(description: "Invalid fixed fixture origin")
    }
    // Every deletion is restricted to an exact service created under this run's UUID.
    var services: Set<String> = []
    defer {
      for service in services {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary)
      }
    }
    let defaultService = prefix + ".default"
    services.insert(defaultService)
    try insert("probe-default", service: defaultService, account: "probe-default")
    let defaultInsertion = try lookup(service: defaultService, account: "probe-default")
    guard defaultInsertion.count == 1, defaultInsertion.first?.group == privateGroup else {
      throw ProbeError(description: "Default insertion did not use the declared first access group")
    }
    var observations: [Observation] = []
    for purpose in [KeychainCredentialStorage.Purpose.magicLink, .biometricCredentials, .client] {
      var names = ["private-only", "shared-only", "private-then-shared", "shared-then-private", "adopted-shared-only", "adopted-private-and-shared", "previous-bundle-only"]
      if purpose == .client {
        names += ["previous-bundle-and-shared", "private-and-previous-bundle-and-shared", "accepted-local-and-shared"]
      }
      for name in names {
        let application = prefix + ".\(purpose.rawValue).\(name)"
        let legacyService = application + ".configured"
        let account = switch purpose {
        case .magicLink: "pendingMagicLinkFlow"
        case .client: "clerkDeviceToken"
        default: "trustedDeviceCredentials"
        }
        let fingerprint = hash("clerk.shared-session-sync.v2\u{1F}\(origin.absoluteString)\u{1F}\(key)")
        let identityService = application + ".clerk.identity.v2." + fingerprint
        services.formUnion([application, legacyService, application + ".clerk.core.v2." + hash(key)])
        func seedPrivate() throws {
          try insert("probe-private", service: legacyService, account: account, group: privateGroup)
        }
        func seedShared() throws {
          try insert("probe-shared", service: legacyService, account: account, group: sharedGroup)
        }
        func seedPreviousBundle() throws {
          try insert("probe-previous-bundle", service: application, account: account, group: privateGroup)
        }
        switch name {
        case "private-only": try seedPrivate()
        case "shared-only", "adopted-shared-only": try seedShared()
        case "private-then-shared", "adopted-private-and-shared": try seedPrivate(); try seedShared()
        case "shared-then-private": try seedShared(); try seedPrivate()
        case "previous-bundle-only": try seedPreviousBundle()
        case "previous-bundle-and-shared": try seedPreviousBundle(); try seedShared()
        case "private-and-previous-bundle-and-shared": try seedPrivate(); try seedPreviousBundle(); try seedShared()
        case "accepted-local-and-shared":
          try seedPrivate(); try seedPreviousBundle(); try seedShared()
          services.insert(identityService)
          try insert(#"{"schema_version":1,"accepted_identity":{"state":"cleared","device_token":"probe-accepted"}}"#, service: identityService, account: "clerkSharedSessionLocalIdentityV2", group: privateGroup)
          try insert("2", service: identityService, account: "clerkSharedSessionSyncAdoptedV2", group: privateGroup)
        default: throw ProbeError(description: "Unknown fixture")
        }
        if name.hasPrefix("adopted-") {
          services.insert(identityService)
          try insert("2", service: identityService, account: "clerkSharedSessionSyncAdoptedV2", group: privateGroup)
        }
        let omitted = try lookup(service: legacyService, account: account)
        let explicitPrivate = try lookup(service: legacyService, account: account, group: privateGroup)
        let explicitShared = try lookup(service: legacyService, account: account, group: sharedGroup)
        let previousBundle = try lookup(service: application, account: account)
        let acceptedLocalIdentity = try lookup(service: identityService, account: "clerkSharedSessionLocalIdentityV2")
        let configuration = LegacyKeychainConfiguration(service: legacyService, accessGroup: sharedGroup, publishableKey: key)
        let storage = KeychainCredentialStorage(publishableKey: key, frontendAPI: origin, applicationIdentifier: application, legacy: configuration, purpose: purpose)
        let migrated = try await storage.read()
        let rebuilt = KeychainCredentialStorage(publishableKey: key, frontendAPI: origin, applicationIdentifier: application, legacy: configuration, purpose: purpose)
        let reconstructed = try await rebuilt.read()
        guard migrated == reconstructed else { throw ProbeError(description: "Reconstruction changed the migrated fixture") }
        try await storage.remove()
        let cleared = KeychainCredentialStorage(publishableKey: key, frontendAPI: origin, applicationIdentifier: application, legacy: configuration, purpose: purpose)
        let afterClear = try await cleared.read()
        guard afterClear == nil else { throw ProbeError(description: "A durable clear reimported a fixture") }
        observations.append(Observation(name: name, purpose: purpose.rawValue, omittedGroup: omitted, explicitPrivate: explicitPrivate, explicitShared: explicitShared, previousBundle: previousBundle, acceptedLocalIdentity: acceptedLocalIdentity, migrated: migrated, reconstructed: reconstructed, afterClear: afterClear))
      }
    }
    for service in services {
      let status = SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else {
        throw ProbeError(description: "Fixture cleanup failed with OSStatus \(status)")
      }
    }
    services.removeAll()
    return Report(schemaVersion: 2, runIdentifier: runID, operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString, privateGroup: privateGroup, sharedGroup: sharedGroup, defaultInsertion: defaultInsertion, observations: observations)
  }
}
