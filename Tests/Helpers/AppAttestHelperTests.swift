@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct AppAttestHelperTests {
  @Test
  func legacySharedKeyIdMigratesToAppLocalStorage() throws {
    configureClerkForTesting()
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    try sharedKeychain.set(
      "legacy-attest-key",
      forKey: ClerkKeychainKey.attestKeyId.rawValue
    )
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain
    )

    #expect(AppAttestHelper.hasKeyId)
    #expect(
      try appLocalKeychain.string(
        forKey: ClerkKeychainKey.attestKeyId.rawValue
      ) == "legacy-attest-key"
    )
  }

  @Test
  func removingKeyIdDeletesAppLocalAndLegacyCopies() throws {
    configureClerkForTesting()
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    try sharedKeychain.set(
      "legacy-attest-key",
      forKey: ClerkKeychainKey.attestKeyId.rawValue
    )
    try appLocalKeychain.set(
      "local-attest-key",
      forKey: ClerkKeychainKey.attestKeyId.rawValue
    )
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain
    )

    try AppAttestHelper.removeKeyId()

    #expect(
      try appLocalKeychain.hasItem(
        forKey: ClerkKeychainKey.attestKeyId.rawValue
      ) == false
    )
    #expect(
      try sharedKeychain.hasItem(
        forKey: ClerkKeychainKey.attestKeyId.rawValue
      ) == false
    )
  }
}
