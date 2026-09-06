import ClerkJSCore
import Foundation
import Testing

struct EnvironmentGatingTests {
  @Test
  func snapshotEnablesEmailAndDisablesPhone() throws {
    let environment = try decodeSnapshotEnvironment()
    #expect(environment.emailIsEnabled)
    #expect(environment.passwordIsEnabled)
    #expect(environment.deleteSelfIsEnabled)
    #expect(!environment.phoneNumberIsEnabled)
    #expect(!environment.passkeyIsEnabled)
    #expect(!environment.passkeyFirstFactorIsEnabled)
    #expect(!environment.mfaIsEnabled)
    #expect(!environment.mfaAuthenticatorAppIsEnabled)
    #expect(!environment.mfaPhoneCodeIsEnabled)
    #expect(!environment.mfaBackupCodeIsEnabled)
    #expect(!environment.usernameIsEnabled)
    #expect(!environment.firstNameIsEnabled)
    #expect(!environment.lastNameIsEnabled)
    #expect(!environment.emailIsImmutable)
    #expect(!environment.phoneNumberIsImmutable)
    #expect(!environment.usernameIsImmutable)
    #expect(!environment.multiSessionModeIsEnabled)
  }

  @Test
  func helpersFollowMutatedAttributeFlags() throws {
    var object = try snapshotObject()
    var authConfig = try #require(object["auth_config"] as? [String: Any])
    authConfig["single_session_mode"] = false
    object["auth_config"] = authConfig

    var userSettings = try #require(object["user_settings"] as? [String: Any])
    var attributes = try #require(userSettings["attributes"] as? [String: Any])
    attributes["email_address"] = try mutatedAttribute(
      attributes["email_address"],
      immutable: true
    )
    attributes["passkey"] = try mutatedAttribute(
      attributes["passkey"],
      enabled: true,
      usedForFirstFactor: true
    )
    attributes["phone_number"] = try mutatedAttribute(
      attributes["phone_number"],
      enabled: true,
      usedForSecondFactor: true,
      immutable: true
    )
    attributes["authenticator_app"] = try mutatedAttribute(
      attributes["authenticator_app"],
      enabled: true,
      usedForSecondFactor: true
    )
    attributes["backup_code"] = try mutatedAttribute(
      attributes["backup_code"],
      enabled: true,
      usedForSecondFactor: true
    )
    attributes["username"] = try mutatedAttribute(
      attributes["username"],
      enabled: true,
      immutable: true
    )
    userSettings["attributes"] = attributes
    userSettings["actions"] = ["delete_self": false, "create_organization": true]
    object["user_settings"] = userSettings

    let environment = try decodeEnvironment(object)
    #expect(environment.multiSessionModeIsEnabled)
    #expect(environment.emailIsImmutable)
    #expect(environment.passkeyIsEnabled)
    #expect(environment.passkeyFirstFactorIsEnabled)
    #expect(environment.phoneNumberIsEnabled)
    #expect(environment.mfaPhoneCodeIsEnabled)
    #expect(environment.mfaAuthenticatorAppIsEnabled)
    #expect(environment.mfaBackupCodeIsEnabled)
    #expect(environment.mfaIsEnabled)
    #expect(environment.usernameIsEnabled)
    #expect(environment.usernameIsImmutable)
    #expect(environment.phoneNumberIsImmutable)
    #expect(!environment.deleteSelfIsEnabled)
  }

  @Test
  func passkeyFirstFactorStaysOffWhenPasskeyIsEnabledWithoutFirstFactor() throws {
    var object = try snapshotObject()
    var userSettings = try #require(object["user_settings"] as? [String: Any])
    var attributes = try #require(userSettings["attributes"] as? [String: Any])
    attributes["passkey"] = try mutatedAttribute(
      attributes["passkey"],
      enabled: true,
      usedForFirstFactor: false
    )
    userSettings["attributes"] = attributes
    object["user_settings"] = userSettings

    let environment = try decodeEnvironment(object)
    #expect(environment.passkeyIsEnabled)
    #expect(!environment.passkeyFirstFactorIsEnabled)
  }
}

private func snapshotURL() throws -> URL {
  try #require(Bundle.module.url(forResource: "environment-snapshot", withExtension: "json"))
}

private func snapshotObject() throws -> [String: Any] {
  try #require(JSONSerialization.jsonObject(with: Data(contentsOf: snapshotURL())) as? [String: Any])
}

private func decodeSnapshotEnvironment() throws -> Environment {
  try JSONDecoder().decode(Environment.self, from: Data(contentsOf: snapshotURL()))
}

private func decodeEnvironment(_ object: [String: Any]) throws -> Environment {
  try JSONDecoder().decode(Environment.self, from: JSONSerialization.data(withJSONObject: object))
}

private func mutatedAttribute(
  _ value: Any?,
  enabled: Bool? = nil,
  usedForFirstFactor: Bool? = nil,
  usedForSecondFactor: Bool? = nil,
  immutable: Bool? = nil
) throws -> [String: Any] {
  var attribute = try #require(value as? [String: Any])
  if let enabled {
    attribute["enabled"] = enabled
  }
  if let usedForFirstFactor {
    attribute["used_for_first_factor"] = usedForFirstFactor
  }
  if let usedForSecondFactor {
    attribute["used_for_second_factor"] = usedForSecondFactor
  }
  if let immutable {
    attribute["immutable"] = immutable
  }
  return attribute
}
