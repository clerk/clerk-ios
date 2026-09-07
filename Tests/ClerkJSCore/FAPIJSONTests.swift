import ClerkJSCore
import Foundation
import Testing

struct FAPIJSONTests {
  @Test
  func normalizeReplacesNullSignInUserData() throws {
    let url = try #require(Bundle.module.url(forResource: "null-user-data-client", withExtension: "json"))
    let data = try Data(contentsOf: url)

    let raw = try JSONDecoder().decode(Client.self, from: data)
    #expect(raw.signIn?.id == "sia_fixture")
    #expect(raw.signIn?.userData.imageUrl == "")
    #expect(raw.signIn?.userData.hasImage == false)

    let client = try FAPIJSON.decodeClient(data)
    #expect(client.id == "client_fixture")
    let signIn = try #require(client.signIn)
    #expect(signIn.id == "sia_fixture")
    #expect(signIn.userData.imageUrl == "")
    #expect(signIn.userData.hasImage == false)
  }

  @Test
  func normalizeLeavesPresentUserData() throws {
    let url = try #require(Bundle.module.url(forResource: "null-user-data-client", withExtension: "json"))
    var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    var signIn = try #require(object["sign_in"] as? [String: Any])
    signIn["user_data"] = [
      "image_url": "https://img.clerk.test/a.png",
      "has_image": true,
      "first_name": "Ada",
    ]
    object["sign_in"] = signIn
    let data = try JSONSerialization.data(withJSONObject: object)

    let client = try FAPIJSON.decodeClient(data)
    let decodedSignIn = try #require(client.signIn)
    #expect(decodedSignIn.userData.imageUrl == "https://img.clerk.test/a.png")
    #expect(decodedSignIn.userData.hasImage)
    #expect(decodedSignIn.userData.firstName == "Ada")
  }

  @Test
  func normalizeReplacesNestedNullUserData() throws {
    let payload: [String: Any] = [
      "user_data": NSNull(),
      "nested": [
        "user_data": NSNull(),
      ],
      "items": [
        ["user_data": NSNull()],
      ],
    ]
    let normalized = try FAPIJSON.normalizeClientJSON(JSONSerialization.data(withJSONObject: payload))
    let object = try #require(JSONSerialization.jsonObject(with: normalized) as? [String: Any])
    let root = try #require(object["user_data"] as? [String: Any])
    #expect(root["image_url"] as? String == "")
    #expect(root["has_image"] as? Bool == false)
    let nested = try #require((object["nested"] as? [String: Any])?["user_data"] as? [String: Any])
    #expect(nested["image_url"] as? String == "")
    let item = try #require((object["items"] as? [[String: Any]])?.first?["user_data"] as? [String: Any])
    #expect(item["has_image"] as? Bool == false)
  }

  @Test
  func normalizeReplacesNullSignInFactorArrays() throws {
    let payload: [String: Any] = [
      "object": "client",
      "id": "client_fixture",
      "sessions": [Any](),
      "sign_in": [
        "object": "sign_in",
        "id": "sia_fixture",
        "status": "needs_first_factor",
        "supported_identifiers": NSNull(),
        "identifier": "user@example.com",
        "user_data": NSNull(),
        "supported_first_factors": NSNull(),
        "supported_second_factors": NSNull(),
        "first_factor_verification": NSNull(),
        "second_factor_verification": NSNull(),
        "created_session_id": NSNull(),
        "created_at": 1_700_000_000_000,
        "updated_at": 1_700_000_000_000,
      ],
      "sign_up": NSNull(),
      "last_active_session_id": NSNull(),
      "created_at": 1_700_000_000_000,
      "updated_at": 1_700_000_000_000,
    ]
    let client = try FAPIJSON.decodeClient(JSONSerialization.data(withJSONObject: payload))
    let signIn = try #require(client.signIn)
    #expect(signIn.supportedIdentifiers.isEmpty)
    #expect(signIn.supportedFirstFactors.isEmpty)
    #expect(signIn.supportedSecondFactors.isEmpty)
  }

  @Test
  func normalizeDefaultsMissingVerificationFields() throws {
    let payload: [String: Any] = [
      "object": "client",
      "id": "client_fixture",
      "sessions": [Any](),
      "sign_in": [
        "object": "sign_in",
        "id": "sia_fixture",
        "status": "needs_first_factor",
        "supported_identifiers": ["email_address"],
        "identifier": "user@example.com",
        "user_data": NSNull(),
        "supported_first_factors": [Any](),
        "supported_second_factors": [Any](),
        "first_factor_verification": [
          "status": "unverified",
          "strategy": "email_code",
        ],
        "second_factor_verification": NSNull(),
        "created_session_id": NSNull(),
        "created_at": 1_700_000_000_000,
        "updated_at": 1_700_000_000_000,
      ],
      "sign_up": NSNull(),
      "last_active_session_id": NSNull(),
      "created_at": 1_700_000_000_000,
      "updated_at": 1_700_000_000_000,
    ]
    let client = try FAPIJSON.decodeClient(JSONSerialization.data(withJSONObject: payload))
    let verification = try #require(client.signIn?.firstFactorVerification)
    #expect(verification.verifiedAtClient == "")
    #expect(verification.error.code == "")
    #expect(verification.object == "verification")
  }

  @Test
  func normalizePassesUnsignedClientThrough() throws {
    let url = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let client = try FAPIJSON.decodeClient(Data(contentsOf: url))
    #expect(client.id == "client_fixture")
    #expect(client.signIn == nil)
    #expect(client.sessions.isEmpty)
  }

  @Test
  func decodeClientReadsSignedInSessionFromFAPIGaps() throws {
    let url = try #require(Bundle.module.url(forResource: "signed-in-client", withExtension: "json"))
    let data = try Data(contentsOf: url)

    let raw = try JSONDecoder().decode(Client.self, from: data)
    #expect(raw.signIn?.id == "sia_fixture")
    #expect(raw.sessions.first?.id == "sess_fixture")
    #expect(raw.sessions.first?.user.id == "user_fixture")

    let client = try FAPIJSON.decodeClient(data)
    #expect(client.id == "client_fixture")
    #expect(client.lastActiveSessionId == "sess_fixture")
    #expect(client.sessions.count == 1)
    let session = try #require(client.sessions.first)
    #expect(session.id == "sess_fixture")
    #expect(session.user.id == "user_fixture")
    #expect(session.user.profileImageId == "")
    #expect(session.user.organizationMemberships.isEmpty)
    #expect(session.user.emailAddresses.map(\.id) == ["idn_email"])
    #expect(session.lastActiveToken.jwt == "header.payload.sig")
    #expect(session.lastActiveToken.id == "")
    let signIn = try #require(client.signIn)
    #expect(signIn.id == "sia_fixture")
    #expect(signIn.identifier == "user@example.com")
    #expect(signIn.createdSessionId == "sess_fixture")
    #expect(signIn.supportedFirstFactors.isEmpty)
  }

  @Test
  func normalizeDoesNotInventSessions() throws {
    let url = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let client = try FAPIJSON.decodeClient(Data(contentsOf: url))
    #expect(client.sessions.isEmpty)
    #expect(client.lastActiveSessionId == nil)
  }

  @Test
  func decodeNativeSettingsDefaultsWhenMissingFromEnvironmentSnapshot() throws {
    let url = try #require(Bundle.module.url(forResource: "environment-snapshot", withExtension: "json"))
    let settings = try FAPIJSON.decodeNativeSettings(fromEnvironmentJSON: Data(contentsOf: url))
    #expect(settings == .default)
  }

  @Test
  func decodeNativeSettingsReadsTrustedDeviceKeys() throws {
    let payload: [String: Any] = [
      "auth_config": [
        "native_settings": [
          "api_enabled": true,
          "trusted_device_sign_in_enabled": true,
          "trusted_device_enrollment_prompt_after_sign_in_enabled": true,
          "trusted_device_enrollment_prompt_after_sign_up_enabled": true,
        ],
      ],
    ]
    let settings = try FAPIJSON.decodeNativeSettings(
      fromEnvironmentJSON: JSONSerialization.data(withJSONObject: payload)
    )
    #expect(settings.apiEnabled)
    #expect(settings.biometricSignInEnabled)
    #expect(settings.biometricCredentialPromptAfterSignInEnabled)
    #expect(settings.biometricCredentialPromptAfterSignUpEnabled)
  }
}
