@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct BiometricCredentialsTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func availabilityReturnsAvailableLocalCredentialWithoutActiveSession() throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = try makeBiometricCredentialsWithLocalCredential()

    let availability = try setup.biometricCredentials.localAvailability()

    #expect(availability.isAvailable == true)
    #expect(availability.unavailableReason == nil)
  }

  @Test
  func availabilityReturnsAvailableWithMultipleLocalCredentials() throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = makeBiometricCredentials()
    try setup.credentialStore.save(localCredential(
      id: "tdc_old",
      localKeyId: "tdlk_old",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_new",
      localKeyId: "tdlk_new",
      createdAt: Date(timeIntervalSinceReferenceDate: 20)
    ))

    let availability = try setup.biometricCredentials.localAvailability()

    #expect(availability.isAvailable == true)
  }

  @Test
  func localAvailabilityDoesNotReconcileServerCredentialWhenSessionIsActive() throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let setup = try makeBiometricCredentialsWithLocalCredential()

    let availability = try setup.biometricCredentials.localAvailability()

    #expect(availability.isAvailable == true)
    #expect(availability.unavailableReason == nil)
    #expect(try setup.credentialStore.credential(id: "tdc_123") != nil)
  }

  @Test
  func availabilityReturnsFeatureDisabledWhenNativeSettingIsOff() throws {
    Clerk.shared.environment = .mock
    Clerk.shared.client = .mockSignedOut
    let setup = try makeBiometricCredentialsWithLocalCredential()

    let availability = try setup.biometricCredentials.localAvailability()

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .nativeAPIDisabled)
  }

  @Test
  func availabilityDeletesMetadataWhenLocalKeyIsMissing() throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = try makeBiometricCredentialsWithLocalCredential(
      keyManager: MockBiometricCredentialKeyManager(hasKey: { _ in false })
    )

    let availability = try setup.biometricCredentials.localAvailability()

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .localKeyMissing)
    #expect(try setup.credentialStore.all().isEmpty)
  }

  @Test
  func availabilityIgnoresCredentialFromDifferentAppIdentifierBeforeCheckingKeys() throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let checkedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(keyManager: MockBiometricCredentialKeyManager(hasKey: { localKeyId in
      checkedLocalKeyIds.withValue { $0.append(localKeyId) }
      return false
    }))
    try setup.credentialStore.save(localCredential(
      id: "tdc_other_app",
      localKeyId: "tdlk_other_app",
      appIdentifier: "com.clerk.other",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let availability = try setup.biometricCredentials.localAvailability()

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .noLocalCredential)
    #expect(checkedLocalKeyIds.value.isEmpty)
    #expect(try setup.credentialStore.credential(id: "tdc_other_app") != nil)
  }

  @Test
  func localAvailabilityUsesUserIDWhenIdentifierHintChanged() throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mock
    let setup = makeBiometricCredentials()
    try setup.credentialStore.save(localCredential(
      id: "tdc_current_user",
      localKeyId: "tdlk_current_user",
      userID: User.mock.id,
      identifierHint: "old@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let availability = try setup.biometricCredentials.currentUserLocalAvailability()

    #expect(availability.isAvailable)
  }

  @Test
  func forgetLocalCredentialsDeletesDeletedUserIDAfterCurrentUserIsCleared() throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let setup = makeBiometricCredentials(keyManager: MockBiometricCredentialKeyManager(deleteKey: { localKeyId in
      deletedLocalKeyIds.withValue { $0.append(localKeyId) }
    }))
    try setup.credentialStore.save(localCredential(
      id: "tdc_deleted",
      localKeyId: "tdlk_deleted",
      userID: User.mock.id,
      identifierHint: "old@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 20)
    ))
    try setup.credentialStore.save(localCredential(
      id: "tdc_other_app",
      localKeyId: "tdlk_other_app",
      userID: User.mock.id,
      appIdentifier: "com.clerk.other",
      identifierHint: "old@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let deletedCount = try setup.biometricCredentials.forgetLocalCredentials(deletedUserID: User.mock.id)

    #expect(deletedCount == 1)
    #expect(deletedLocalKeyIds.value == ["tdlk_deleted"])
    #expect(try setup.credentialStore.credential(id: "tdc_deleted") == nil)
    #expect(try setup.credentialStore.credential(id: "tdc_other_app") != nil)
  }

  @Test
  func availabilityUsesStoredCredentialPolicy() throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let checkedPolicies = LockIsolated<[BiometricCredentialPolicy]>([])
    let keyManager = MockBiometricCredentialKeyManager(
      isSupportedForPolicy: { policy in
        checkedPolicies.withValue { $0.append(policy) }
        return policy == .biometryOrDevicePasscode
      }
    )
    let localCredential = BiometricCredentialLocalRecord(
      id: "tdc_123",
      localKeyId: "tdlk_mock",
      userID: User.mock.id,
      appIdentifier: "com.clerk.example",
      policy: .biometryOrDevicePasscode,
      createdAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890),
      updatedAt: Date(timeIntervalSinceReferenceDate: 1_234_567_890)
    )
    let setup = try makeBiometricCredentialsWithLocalCredential(
      keyManager: keyManager,
      localCredential: localCredential
    )

    let availability = try setup.biometricCredentials.localAvailability()

    #expect(availability.isAvailable)
    #expect(checkedPolicies.value == [.biometryOrDevicePasscode])
  }

  @Test
  func availabilityReturnsNoLocalCredentialWhenIdentifierHintDoesNotMatch() throws {
    Clerk.shared.environment = enabledBiometricCredentialEnvironment()
    Clerk.shared.client = .mockSignedOut
    let setup = try makeBiometricCredentialsWithLocalCredential(localCredential: localCredential(
      id: "tdc_123",
      localKeyId: "tdlk_mock",
      identifierHint: "sean@example.com",
      createdAt: Date(timeIntervalSinceReferenceDate: 10)
    ))

    let availability = try setup.biometricCredentials.localAvailability(identifierHint: "sam@example.com")

    #expect(availability.isAvailable == false)
    #expect(availability.unavailableReason == .noLocalCredential)
  }
}

private func enabledBiometricCredentialEnvironment() -> Clerk.Environment {
  var environment = Clerk.Environment.mock
  environment.authConfig.nativeSettings = .init(
    apiEnabled: true,
    biometricSignInEnabled: true
  )
  return environment
}

private func localCredential(
  id: String,
  localKeyId: String,
  userID: String = User.mock.id,
  appIdentifier: String = "com.clerk.example",
  identifierHint: String? = nil,
  createdAt: Date
) -> BiometricCredentialLocalRecord {
  BiometricCredentialLocalRecord(
    id: id,
    localKeyId: localKeyId,
    userID: userID,
    appIdentifier: appIdentifier,
    identifierHint: identifierHint,
    createdAt: createdAt,
    updatedAt: createdAt
  )
}

@MainActor
private func makeBiometricCredentialsWithLocalCredential(keyManager: MockBiometricCredentialKeyManager = .init(), localCredential: BiometricCredentialLocalRecord = .mock) throws -> (biometricCredentials: BiometricCredentials, credentialStore: BiometricCredentialLocalStore) {
  let setup = makeBiometricCredentials(keyManager: keyManager)
  try setup.credentialStore.save(localCredential)
  return setup
}

@MainActor
private func makeBiometricCredentials(keyManager: MockBiometricCredentialKeyManager = .init()) -> (biometricCredentials: BiometricCredentials, credentialStore: BiometricCredentialLocalStore) {
  let store = BiometricCredentialLocalStore(keychain: InMemoryKeychain())
  let credentials = BiometricCredentials(keyManager: keyManager, credentialStore: store, appIdentifierProvider: { "com.clerk.example" })
  return (credentials, store)
}
