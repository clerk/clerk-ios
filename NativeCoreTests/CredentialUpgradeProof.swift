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
    let fingerprint = hash("clerk.shared-session-sync.v2\u{1F}\(origin.absoluteString)\u{1F}\(key)")
    let identityService = application + ".clerk.identity.v2." + fingerprint
    let recoveryService = application + ".clerk.shared-session-clear-recovery.v1"
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
    let biometrics = KeychainCredentialStorage(publishableKey: key, frontendAPI: origin, applicationIdentifier: application, legacy: .init(publishableKey: key), purpose: .biometricCredentials)
    switch mode {
    case "seed", "seed-clearing", "seed-token-only":
      // These persisted keys follow the previous major's clerkEncoder
      // (.convertToSnakeCase), not the new runtime's projection format.
      let client: [String: Any] = ["id": "client_upgrade_fixture", "sessions": [], "updated_at": 1_700_000_000_000]
      let identity: [String: Any] = mode == "seed-token-only"
        ? ["state": "cleared", "device_token": "upgrade-fixture-credential"]
        : ["state": "present", "device_token": "upgrade-fixture-credential", "client": client]
      let record: [String: Any] = ["schema_version": 1, "accepted_identity": identity, "requires_legacy_adoption_publication": false]
      try seed(identityService, "clerkSharedSessionLocalIdentityV2", JSONSerialization.data(withJSONObject: record))
      if mode == "seed-clearing" {
        let intent: [String: Any] = ["schema_version": 1, "local_identity_service": identityService, "slot_service": "fixture.shared.slot", "slot_access_group": "fixture.group", "slot_account": "fixture.owner", "instance_fingerprint": fingerprint, "owner_identifier": application]
        try seed(recoveryService, "clerkSharedSessionOwnerSlotClearIntentV1", JSONSerialization.data(withJSONObject: intent))
      }
      try seed(application, "clerkDeviceToken", Data("unscoped-fixture-must-not-restore".utf8))
      try seed(application, "pendingMagicLinkFlow", Data("fixture-pending-magic-link".utf8))
      try seed(application, "trustedDeviceCredentials", Data("fixture-biometric-metadata".utf8))
    case "restore":
      let token = try await storage.read()
      precondition(token == "upgrade-fixture-credential")
      let pending = try await magic.read()
      precondition(pending == "fixture-pending-magic-link")
      let local = try await biometrics.read()
      precondition(local == "fixture-biometric-metadata")
      let other = KeychainCredentialStorage(publishableKey: key + "-other", frontendAPI: origin, applicationIdentifier: application)
      let otherToken = try await other.read()
      precondition(otherToken == nil)
    case "clear": try await storage.remove(); try await magic.remove(); try await biometrics.remove()
    case "assert-pending-clear":
      let token = try await storage.read()
      precondition(token == nil)
    case "assert-cleared":
      let token = try await storage.read()
      precondition(token == nil)
      let pending = try await magic.read()
      precondition(pending == nil)
      let local = try await biometrics.read()
      precondition(local == nil)
    case "cleanup":
      for (service, account) in [(identityService, "clerkSharedSessionLocalIdentityV2"), (recoveryService, "clerkSharedSessionOwnerSlotClearIntentV1"), (application, "clerkDeviceToken"), (application, "pendingMagicLinkFlow"), (application, "trustedDeviceCredentials"), (application + ".clerk.core.v2." + hash(key), "biometricCredentials"), (application + ".clerk.core.v2." + hash(key), "magicLink"), (application + ".clerk.core.v2." + hash(key), "client"), (application + ".clerk.core.v2." + hash(key + "-other"), "client")] {
        SecItemDelete(item(service, account) as CFDictionary)
      }
    default: throw CoreError(code: "unknown_test_mode")
    }
    print("PASS: isolated keychain upgrade fixture \(mode)")
  }
}
