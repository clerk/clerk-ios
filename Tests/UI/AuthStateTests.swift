#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct AuthStateTests {
  @Test
  func persistedPrefillLoadsStoredValues() {
    let defaults = makeDefaults()
    AuthStartStorage.storeIdentifier("persisted@example.com", defaults: defaults)
    AuthStartStorage.storePhoneNumber("+15555550123", defaults: defaults)
    LastUsedAuth.storeIdentifierType(.email, defaults: defaults)

    let authState = AuthState(
      mode: .signInOrUp,
      identifierPrefill: .persisted,
      defaults: defaults
    )

    #expect(authState.authStartIdentifier == "persisted@example.com")
    #expect(authState.authStartPhoneNumber == "+15555550123")
    #expect(authState.preferredStartField == .automatic)
    #expect(LastUsedAuth.retrieveStoredIdentifierType(defaults: defaults) == .email)
  }

  @Test
  func emptyPrefillClearsStoredValues() {
    let defaults = makeDefaults()
    AuthStartStorage.storeIdentifier("persisted@example.com", defaults: defaults)
    AuthStartStorage.storePhoneNumber("+15555550123", defaults: defaults)
    LastUsedAuth.storeIdentifierType(.phone, defaults: defaults)

    let authState = AuthState(
      mode: .signInOrUp,
      identifierPrefill: .empty,
      defaults: defaults
    )

    #expect(authState.authStartIdentifier.isEmpty)
    #expect(authState.authStartPhoneNumber.isEmpty)
    #expect(authState.preferredStartField == .automatic)
    #expect(AuthStartStorage.loadPrefillState(defaults: defaults) == .init(
      identifier: "persisted@example.com",
      phoneNumber: "+15555550123"
    ))

    authState.applyInitialPersistenceIfNeeded()

    #expect(AuthStartStorage.loadPrefillState(defaults: defaults) == .init(
      identifier: "",
      phoneNumber: ""
    ))
    #expect(LastUsedAuth.retrieveStoredIdentifierType(defaults: defaults) == .phone)
  }

  @Test
  func clearLastUsedAuthBehaviorRemovesStoredLastUsedType() {
    let defaults = makeDefaults()
    LastUsedAuth.storeIdentifierType(.email, defaults: defaults)

    let authState = AuthState(
      mode: .signInOrUp,
      identifierPrefill: .persisted,
      lastUsedAuthBehavior: .clear,
      defaults: defaults
    )

    #expect(LastUsedAuth.retrieveStoredIdentifierType(defaults: defaults) == .email)

    authState.applyInitialPersistenceIfNeeded()

    #expect(LastUsedAuth.retrieveStoredIdentifierType(defaults: defaults) == nil)
  }

  @Test
  func preserveLastUsedAuthBehaviorKeepsStoredLastUsedType() {
    let defaults = makeDefaults()
    LastUsedAuth.storeIdentifierType(.email, defaults: defaults)

    let authState = AuthState(
      mode: .signInOrUp,
      identifierPrefill: .empty,
      lastUsedAuthBehavior: .preserve,
      defaults: defaults
    )

    authState.applyInitialPersistenceIfNeeded()

    #expect(LastUsedAuth.retrieveStoredIdentifierType(defaults: defaults) == .email)
  }

  @Test
  func identifierPrefillOverridesStoredValuesWithoutChangingLastUsedType() {
    let defaults = makeDefaults()
    AuthStartStorage.storePhoneNumber("+15555550123", defaults: defaults)
    LastUsedAuth.storeIdentifierType(.phone, defaults: defaults)

    let authState = AuthState(
      mode: .signInOrUp,
      identifierPrefill: .identifier("person@example.com"),
      defaults: defaults
    )

    #expect(authState.authStartIdentifier == "person@example.com")
    #expect(authState.authStartPhoneNumber.isEmpty)
    #expect(authState.preferredStartField == .identifier)
    #expect(AuthStartStorage.loadPrefillState(defaults: defaults) == .init(
      identifier: "",
      phoneNumber: "+15555550123"
    ))

    authState.applyInitialPersistenceIfNeeded()

    #expect(AuthStartStorage.loadPrefillState(defaults: defaults) == .init(
      identifier: "person@example.com",
      phoneNumber: ""
    ))
    #expect(LastUsedAuth.retrieveStoredIdentifierType(defaults: defaults) == .phone)
  }

  @Test
  func phoneNumberPrefillOverridesStoredValuesWithoutChangingLastUsedType() {
    let defaults = makeDefaults()
    AuthStartStorage.storeIdentifier("persisted@example.com", defaults: defaults)
    LastUsedAuth.storeIdentifierType(.email, defaults: defaults)

    let authState = AuthState(
      mode: .signInOrUp,
      identifierPrefill: .phoneNumber("+15555550123"),
      defaults: defaults
    )

    #expect(authState.authStartIdentifier.isEmpty)
    #expect(authState.authStartPhoneNumber == "+15555550123")
    #expect(authState.preferredStartField == .phoneNumber)
    #expect(AuthStartStorage.loadPrefillState(defaults: defaults) == .init(
      identifier: "persisted@example.com",
      phoneNumber: ""
    ))

    authState.applyInitialPersistenceIfNeeded()

    #expect(AuthStartStorage.loadPrefillState(defaults: defaults) == .init(
      identifier: "",
      phoneNumber: "+15555550123"
    ))
    #expect(LastUsedAuth.retrieveStoredIdentifierType(defaults: defaults) == .email)
  }

  @Test
  func updatingIdentifierFieldPersistsValue() {
    let defaults = makeDefaults()
    let authState = AuthState(
      mode: .signInOrUp,
      identifierPrefill: .empty,
      defaults: defaults
    )

    authState.authStartIdentifier = "updated@example.com"

    #expect(AuthStartStorage.loadPrefillState(defaults: defaults).identifier == "updated@example.com")
  }

  @Test
  func updatingPhoneFieldPersistsValue() {
    let defaults = makeDefaults()
    let authState = AuthState(
      mode: .signInOrUp,
      identifierPrefill: .empty,
      defaults: defaults
    )

    authState.authStartPhoneNumber = "+15555550123"

    #expect(AuthStartStorage.loadPrefillState(defaults: defaults).phoneNumber == "+15555550123")
  }

  @Test
  func preferredStartFieldIdentifierFallsBackToPhoneWhenIdentifierAuthIsDisabled() {
    let preferredStartField = AuthState.PreferredStartField.identifier.normalized(
      emailOrUsernameEnabled: false,
      phoneNumberEnabled: true
    )

    #expect(preferredStartField == .phoneNumber)
  }

  @Test
  func preferredStartFieldPhoneFallsBackToIdentifierWhenPhoneAuthIsDisabled() {
    let preferredStartField = AuthState.PreferredStartField.phoneNumber.normalized(
      emailOrUsernameEnabled: true,
      phoneNumberEnabled: false
    )

    #expect(preferredStartField == .identifier)
  }

  @Test
  func preferredStartFieldFallsBackToAutomaticWhenNoCompatibleFactorIsEnabled() {
    let identifierPreferredStartField = AuthState.PreferredStartField.identifier.normalized(
      emailOrUsernameEnabled: false,
      phoneNumberEnabled: false
    )
    let phonePreferredStartField = AuthState.PreferredStartField.phoneNumber.normalized(
      emailOrUsernameEnabled: false,
      phoneNumberEnabled: false
    )

    #expect(identifierPreferredStartField == .automatic)
    #expect(phonePreferredStartField == .automatic)
  }

  private func makeDefaults(fileID: String = #fileID, line: Int = #line) -> UserDefaults {
    let suiteName = "AuthStateTests.\(fileID).\(line).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}

#endif
