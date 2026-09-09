import ClerkKit
import CryptoKit
import Foundation
import Security

@MainActor enum CredentialUpgradeProof {
  static func run(mode: String, fixture: String) async throws {
    guard UUID(uuidString: fixture) != nil else { throw CoreError(code: "invalid_test_namespace") }
    let application = "com.clerk.native-upgrade-proof.\(fixture)"
    let key = "pk_test_fixture_\(fixture)"
    let origin = URL(string: "https://native-core.clerk.accounts.dev")!
    let hash: (String) -> String = { SHA256.hash(data: Data($0.utf8)).map { String(format: "%02x", $0) }.joined() }
    let identityService = application + ".clerk.identity.v2." + hash("clerk.shared-session-sync.v2\u{1F}\(origin.absoluteString)\u{1F}\(key)")
    func item(_ service: String, _ account: String) -> [String: Any] {
      [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    func seed(_ service: String, _ account: String, _ data: Data) throws {
      let query = item(service, account)
      SecItemDelete(query as CFDictionary)
      var insertion = query
      insertion[kSecValueData as String] = data
      insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      let status = SecItemAdd(insertion as CFDictionary, nil)
      guard status == errSecSuccess else { throw CoreError(code: "fixture_seed_failed_\(status)") }
    }
    let storage = KeychainCredentialStorage(publishableKey: key, frontendAPI: origin, applicationIdentifier: application)
    let magic = KeychainCredentialStorage(publishableKey: key, frontendAPI: origin, applicationIdentifier: application, legacy: .init(publishableKey: key), purpose: .magicLink)
    switch mode {
    case "seed":
      let record: [String: Any] = ["schemaVersion": 1, "acceptedIdentity": ["state": "present", "deviceToken": "upgrade-fixture-credential"], "requiresLegacyAdoptionPublication": false]
      try seed(identityService, "clerkSharedSessionLocalIdentityV2", JSONSerialization.data(withJSONObject: record))
      try seed(application, "clerkDeviceToken", Data("unscoped-fixture-must-not-restore".utf8))
      try seed(application, "pendingMagicLinkFlow", Data("fixture-pending-magic-link".utf8))
    case "restore":
      let token = try await storage.read()
      precondition(token == "upgrade-fixture-credential")
      let pending = try await magic.read()
      precondition(pending == "fixture-pending-magic-link")
      let other = KeychainCredentialStorage(publishableKey: key + "-other", frontendAPI: origin, applicationIdentifier: application)
      let otherToken = try await other.read()
      precondition(otherToken == nil)
    case "clear": try await storage.remove(); try await magic.remove()
    case "assert-cleared":
      let token = try await storage.read()
      precondition(token == nil)
      let pending = try await magic.read()
      precondition(pending == nil)
    case "cleanup":
      for (service, account) in [(identityService, "clerkSharedSessionLocalIdentityV2"), (application, "clerkDeviceToken"), (application, "pendingMagicLinkFlow"), (application + ".clerk.core.v2." + hash(key), "magicLink"), (application + ".clerk.core.v2." + hash(key), "client"), (application + ".clerk.core.v2." + hash(key + "-other"), "client")] {
        SecItemDelete(item(service, account) as CFDictionary)
      }
    default: throw CoreError(code: "unknown_test_mode")
    }
    print("PASS: isolated keychain upgrade fixture \(mode)")
  }
}
