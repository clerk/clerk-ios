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
    AuthStartStorage.storeIdentifierType("email", defaults: defaults)

    let authState = AuthState(
      mode: .signInOrUp,
      identifierPrefill: .persisted,
      defaults: defaults
    )

    #expect(authState.authStartIdentifier == "persisted@example.com")
    #expect(authState.authStartPhoneNumber == "+15555550123")
    #expect(authState.preferredStartField == .automatic)
  }

  @Test
  func emptyPrefillClearsStoredValues() {
    let defaults = makeDefaults()
    AuthStartStorage.storeIdentifier("persisted@example.com", defaults: defaults)
    AuthStartStorage.storePhoneNumber("+15555550123", defaults: defaults)
    AuthStartStorage.storeIdentifierType("phone", defaults: defaults)

    let authState = AuthState(
      mode: .signInOrUp,
      identifierPrefill: .empty,
      defaults: defaults
    )

    #expect(authState.authStartIdentifier.isEmpty)
    #expect(authState.authStartPhoneNumber.isEmpty)
    #expect(authState.preferredStartField == .automatic)
    #expect(AuthStartStorage.loadPrefillState(defaults: defaults) == .init(
      identifier: "",
      phoneNumber: "",
      identifierType: nil
    ))
  }

  @Test
  func identifierPrefillOverridesStoredValuesAndTracksEmailType() {
    let defaults = makeDefaults()
    AuthStartStorage.storePhoneNumber("+15555550123", defaults: defaults)
    AuthStartStorage.storeIdentifierType("phone", defaults: defaults)

    let authState = AuthState(
      mode: .signInOrUp,
      identifierPrefill: .identifier("person@example.com"),
      defaults: defaults
    )

    #expect(authState.authStartIdentifier == "person@example.com")
    #expect(authState.authStartPhoneNumber.isEmpty)
    #expect(authState.preferredStartField == .identifier)
    #expect(AuthStartStorage.loadPrefillState(defaults: defaults) == .init(
      identifier: "person@example.com",
      phoneNumber: "",
      identifierType: "email"
    ))
  }

  @Test
  func phoneNumberPrefillOverridesStoredValuesAndTracksPhoneType() {
    let defaults = makeDefaults()
    AuthStartStorage.storeIdentifier("persisted@example.com", defaults: defaults)
    AuthStartStorage.storeIdentifierType("email", defaults: defaults)

    let authState = AuthState(
      mode: .signInOrUp,
      identifierPrefill: .phoneNumber("+15555550123"),
      defaults: defaults
    )

    #expect(authState.authStartIdentifier.isEmpty)
    #expect(authState.authStartPhoneNumber == "+15555550123")
    #expect(authState.preferredStartField == .phoneNumber)
    #expect(AuthStartStorage.loadPrefillState(defaults: defaults) == .init(
      identifier: "",
      phoneNumber: "+15555550123",
      identifierType: "phone"
    ))
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

  private func makeDefaults(fileID: String = #fileID, line: Int = #line) -> UserDefaults {
    let suiteName = "AuthStateTests.\(fileID).\(line).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}

#endif
