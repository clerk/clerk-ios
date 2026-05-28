#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
struct AuthStateConfigurationTests {
  @Test
  func defaultConfigurationLoadsPersistedValues() {
    let defaults = makeUserDefaults()
    defaults.set("stored@example.com", forKey: AuthState.identifierStorageKey)
    defaults.set("15555550100", forKey: AuthState.phoneNumberStorageKey)
    defaults.set(true, forKey: AuthState.phoneNumberFieldIsActiveStorageKey)

    let authState = AuthState(userDefaults: defaults)

    #expect(authState.authStartIdentifier == "stored@example.com")
    #expect(authState.authStartPhoneNumber == "15555550100")
    #expect(authState.authStartPhoneNumberFieldIsActive)
  }

  @Test
  func defaultConfigurationPersistsEdits() {
    let defaults = makeUserDefaults()
    let authState = AuthState(userDefaults: defaults)

    authState.authStartIdentifier = "edited@example.com"
    authState.authStartPhoneNumber = "16666660123"
    authState.authStartPhoneNumberFieldIsActive = true

    #expect(defaults.string(forKey: AuthState.identifierStorageKey) == "edited@example.com")
    #expect(defaults.string(forKey: AuthState.phoneNumberStorageKey) == "16666660123")
    #expect(defaults.bool(forKey: AuthState.phoneNumberFieldIsActiveStorageKey))
  }

  @Test
  func initialEmailOverridesPersistedValues() {
    let defaults = makeUserDefaults()
    defaults.set("stored@example.com", forKey: AuthState.identifierStorageKey)
    defaults.set("15555550100", forKey: AuthState.phoneNumberStorageKey)

    let authState = AuthState(userDefaults: defaults)
    authState.configure(AuthConfig(
      initialIdentifier: "seed@example.com"
    ))

    #expect(authState.authStartIdentifier == "seed@example.com")
    #expect(authState.authStartPhoneNumber.isEmpty)
    #expect(defaults.string(forKey: AuthState.identifierStorageKey) == "seed@example.com")
  }

  @Test
  func initialPhoneNumberOverridesPersistedValues() {
    let defaults = makeUserDefaults()
    defaults.set("stored@example.com", forKey: AuthState.identifierStorageKey)
    defaults.set("15555550100", forKey: AuthState.phoneNumberStorageKey)

    let authState = AuthState(userDefaults: defaults)
    authState.configure(AuthConfig(
      initialIdentifier: "+17777770123"
    ))

    #expect(authState.authStartPhoneNumber == "+17777770123")
    #expect(authState.authStartIdentifier.isEmpty)
  }

  @Test
  func disablingPersistenceClearsStoredValues() {
    let defaults = makeUserDefaults()
    defaults.set("stored@example.com", forKey: AuthState.identifierStorageKey)
    defaults.set("15555550100", forKey: AuthState.phoneNumberStorageKey)
    defaults.set(true, forKey: AuthState.phoneNumberFieldIsActiveStorageKey)
    LastUsedAuth.storeIdentifierType(.email, userDefaults: defaults)

    let authState = AuthState(userDefaults: defaults)
    authState.configure(AuthConfig(
      persistsIdentifiers: false
    ))

    #expect(authState.authStartIdentifier.isEmpty)
    #expect(authState.authStartPhoneNumber.isEmpty)
    #expect(!authState.authStartPhoneNumberFieldIsActive)
    #expect(defaults.string(forKey: AuthState.identifierStorageKey) == nil)
    #expect(defaults.string(forKey: AuthState.phoneNumberStorageKey) == nil)
    #expect(defaults.object(forKey: AuthState.phoneNumberFieldIsActiveStorageKey) == nil)
    #expect(LastUsedAuth.retrieveStoredIdentifierType(userDefaults: defaults) == nil)
  }

  @Test
  func disablingPersistenceSuppressesFutureWrites() {
    let defaults = makeUserDefaults()
    let authState = AuthState(userDefaults: defaults)
    authState.configure(AuthConfig(
      persistsIdentifiers: false
    ))

    authState.authStartIdentifier = "new@example.com"
    authState.authStartPhoneNumber = "19999990123"
    authState.authStartPhoneNumberFieldIsActive = true

    #expect(defaults.string(forKey: AuthState.identifierStorageKey) == nil)
    #expect(defaults.string(forKey: AuthState.phoneNumberStorageKey) == nil)
    #expect(defaults.object(forKey: AuthState.phoneNumberFieldIsActiveStorageKey) == nil)
  }

  @Test
  func disablingPersistenceWithInitialEmailShowsButDoesNotStore() {
    let defaults = makeUserDefaults()
    defaults.set("stored@example.com", forKey: AuthState.identifierStorageKey)
    defaults.set("15555550100", forKey: AuthState.phoneNumberStorageKey)
    defaults.set(true, forKey: AuthState.phoneNumberFieldIsActiveStorageKey)
    LastUsedAuth.storeIdentifierType(.phone, userDefaults: defaults)

    let authState = AuthState(userDefaults: defaults)
    authState.configure(AuthConfig(
      initialIdentifier: "seed@example.com",
      persistsIdentifiers: false
    ))

    #expect(authState.authStartIdentifier == "seed@example.com")
    #expect(authState.authStartPhoneNumber.isEmpty)
    #expect(defaults.string(forKey: AuthState.identifierStorageKey) == nil)
    #expect(defaults.string(forKey: AuthState.phoneNumberStorageKey) == nil)
    #expect(defaults.object(forKey: AuthState.phoneNumberFieldIsActiveStorageKey) == nil)
    #expect(LastUsedAuth.retrieveStoredIdentifierType(userDefaults: defaults) == nil)
  }

  @Test
  func configurationStoresUnsafeMetadata() {
    let defaults = makeUserDefaults()
    let authState = AuthState(userDefaults: defaults)
    let metadata: JSON = ["plan": "pro"]

    authState.configure(AuthConfig(unsafeMetadata: metadata))

    #expect(authState.unsafeMetadata == metadata)
  }

  @Test
  func configurationCanBeAppliedDuringInitialization() {
    let defaults = makeUserDefaults()
    defaults.set("stored@example.com", forKey: AuthState.identifierStorageKey)
    defaults.set("15555550100", forKey: AuthState.phoneNumberStorageKey)
    LastUsedAuth.storeIdentifierType(.phone, userDefaults: defaults)
    let metadata: JSON = ["plan": "pro"]

    let authState = AuthState(
      config: AuthConfig(
        initialIdentifier: "seed@example.com",
        persistsIdentifiers: false,
        unsafeMetadata: metadata
      ),
      userDefaults: defaults
    )

    #expect(authState.authStartIdentifier == "seed@example.com")
    #expect(authState.authStartPhoneNumber.isEmpty)
    #expect(authState.persistsIdentifiers == false)
    #expect(authState.hasInitialValues == true)
    #expect(authState.unsafeMetadata == metadata)
    #expect(defaults.string(forKey: AuthState.identifierStorageKey) == nil)
    #expect(defaults.string(forKey: AuthState.phoneNumberStorageKey) == nil)
    #expect(LastUsedAuth.retrieveStoredIdentifierType(userDefaults: defaults) == nil)
  }

  private func makeUserDefaults() -> UserDefaults {
    let suiteName = "AuthStateConfigurationTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}

#endif
