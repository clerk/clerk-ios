#if os(iOS)

@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
@Suite(.tags(.uiState, .unit))
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
  func initialEmailOverridesPersistedValues() {
    let defaults = makeUserDefaults()
    defaults.set("stored@example.com", forKey: AuthState.identifierStorageKey)
    defaults.set("15555550100", forKey: AuthState.phoneNumberStorageKey)

    let authState = AuthState(userDefaults: defaults)
    authState.configure(AuthIdentifierConfig(
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
    authState.configure(AuthIdentifierConfig(
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
    LastUsedAuth.storeIdentifierType(.email, userDefaults: defaults)

    let authState = AuthState(userDefaults: defaults)
    authState.configure(AuthIdentifierConfig(
      persistsIdentifiers: false
    ))

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
    authState.configure(AuthIdentifierConfig(
      persistsIdentifiers: false
    ))

    authState.authStartIdentifier = "new@example.com"
    authState.authStartPhoneNumber = "19999990123"

    #expect(defaults.string(forKey: AuthState.identifierStorageKey) == nil)
    #expect(defaults.string(forKey: AuthState.phoneNumberStorageKey) == nil)
  }

  @Test
  func disablingPersistenceWithInitialEmailShowsButDoesNotStore() {
    let defaults = makeUserDefaults()
    defaults.set("stored@example.com", forKey: AuthState.identifierStorageKey)
    defaults.set("15555550100", forKey: AuthState.phoneNumberStorageKey)
    LastUsedAuth.storeIdentifierType(.phone, userDefaults: defaults)

    let authState = AuthState(userDefaults: defaults)
    authState.configure(AuthIdentifierConfig(
      initialIdentifier: "seed@example.com",
      persistsIdentifiers: false
    ))

    #expect(authState.authStartIdentifier == "seed@example.com")
    #expect(authState.authStartPhoneNumber.isEmpty)
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
