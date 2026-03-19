#if os(iOS)

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

    let authState = AuthState(userDefaults: defaults)

    #expect(authState.authStartIdentifier == "stored@example.com")
    #expect(authState.authStartPhoneNumber == "15555550100")
  }

  @Test
  func defaultConfigurationPersistsEdits() {
    let defaults = makeUserDefaults()
    let authState = AuthState(userDefaults: defaults)

    authState.authStartIdentifier = "edited@example.com"
    authState.authStartPhoneNumber = "16666660123"

    #expect(defaults.string(forKey: AuthState.identifierStorageKey) == "edited@example.com")
    #expect(defaults.string(forKey: AuthState.phoneNumberStorageKey) == "16666660123")
  }

  @Test
  func initialValuesOverridePersistedValues() {
    let defaults = makeUserDefaults()
    defaults.set("stored@example.com", forKey: AuthState.identifierStorageKey)
    defaults.set("15555550100", forKey: AuthState.phoneNumberStorageKey)

    let authState = AuthState(userDefaults: defaults)
    authState.configure(
      initialIdentifier: "seed@example.com",
      initialPhoneNumber: "17777770123",
      persistsIdentifiers: true
    )

    #expect(authState.authStartIdentifier == "seed@example.com")
    #expect(authState.authStartPhoneNumber == "17777770123")
    #expect(defaults.string(forKey: AuthState.identifierStorageKey) == "seed@example.com")
    #expect(defaults.string(forKey: AuthState.phoneNumberStorageKey) == "17777770123")
  }

  @Test
  func disablingPersistenceClearsStoredValues() {
    let defaults = makeUserDefaults()
    defaults.set("stored@example.com", forKey: AuthState.identifierStorageKey)
    defaults.set("15555550100", forKey: AuthState.phoneNumberStorageKey)
    LastUsedAuth.storeIdentifierType(.email, userDefaults: defaults)

    let authState = AuthState(userDefaults: defaults)
    authState.configure(
      initialIdentifier: nil,
      initialPhoneNumber: nil,
      persistsIdentifiers: false
    )

    #expect(authState.authStartIdentifier.isEmpty)
    #expect(authState.authStartPhoneNumber.isEmpty)
    #expect(defaults.string(forKey: AuthState.identifierStorageKey) == nil)
    #expect(defaults.string(forKey: AuthState.phoneNumberStorageKey) == nil)
    #expect(LastUsedAuth.retrieveStoredIdentifierType(userDefaults: defaults) == nil)
  }

  @Test
  func disablingPersistenceSuppressesFutureWrites() {
    let defaults = makeUserDefaults()
    let authState = AuthState(userDefaults: defaults)
    authState.configure(
      initialIdentifier: nil,
      initialPhoneNumber: nil,
      persistsIdentifiers: false
    )

    authState.authStartIdentifier = "new@example.com"
    authState.authStartPhoneNumber = "19999990123"

    #expect(defaults.string(forKey: AuthState.identifierStorageKey) == nil)
    #expect(defaults.string(forKey: AuthState.phoneNumberStorageKey) == nil)
  }

  @Test
  func disablingPersistenceWithInitialValuesShowsButDoesNotStore() {
    let defaults = makeUserDefaults()
    defaults.set("stored@example.com", forKey: AuthState.identifierStorageKey)
    defaults.set("15555550100", forKey: AuthState.phoneNumberStorageKey)
    LastUsedAuth.storeIdentifierType(.phone, userDefaults: defaults)

    let authState = AuthState(userDefaults: defaults)
    authState.configure(
      initialIdentifier: "seed@example.com",
      initialPhoneNumber: "17777770123",
      persistsIdentifiers: false
    )

    #expect(authState.authStartIdentifier == "seed@example.com")
    #expect(authState.authStartPhoneNumber == "17777770123")
    #expect(defaults.string(forKey: AuthState.identifierStorageKey) == nil)
    #expect(defaults.string(forKey: AuthState.phoneNumberStorageKey) == nil)
    #expect(LastUsedAuth.retrieveStoredIdentifierType(userDefaults: defaults) == nil)
  }

  @Test
  func initialPhoneNumberClearsStoredIdentifier() {
    let defaults = makeUserDefaults()
    defaults.set("stored@example.com", forKey: AuthState.identifierStorageKey)

    let authState = AuthState(userDefaults: defaults)
    authState.configure(
      initialIdentifier: nil,
      initialPhoneNumber: "15555550100",
      persistsIdentifiers: true
    )

    #expect(authState.authStartIdentifier.isEmpty)
    #expect(authState.authStartPhoneNumber == "15555550100")
  }

  @Test
  func initialIdentifierClearsStoredPhoneNumber() {
    let defaults = makeUserDefaults()
    defaults.set("15555550100", forKey: AuthState.phoneNumberStorageKey)

    let authState = AuthState(userDefaults: defaults)
    authState.configure(
      initialIdentifier: "seed@example.com",
      initialPhoneNumber: nil,
      persistsIdentifiers: true
    )

    #expect(authState.authStartIdentifier == "seed@example.com")
    #expect(authState.authStartPhoneNumber.isEmpty)
  }

  private func makeUserDefaults() -> UserDefaults {
    let suiteName = "AuthStateConfigurationTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}

#endif
