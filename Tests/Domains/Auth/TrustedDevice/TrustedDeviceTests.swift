@testable import ClerkKit
import Foundation
import Testing

struct TrustedDeviceTests {
  private let decoder = JSONDecoder.clerkDecoder
  private let encoder = JSONEncoder.clerkEncoder

  @Test
  func trustedDeviceDecodesBackendShape() throws {
    let data = Data(
      """
      {
        "id": "tdc_123",
        "object": "trusted_device",
        "platform": "ios",
        "app_identifier": "com.clerk.example",
        "name": "Sean's iPhone",
        "algorithm": "ES256",
        "status": "active",
        "created_at": 1710000000000,
        "updated_at": 1710000001000,
        "last_used_at": 1710000002000,
        "revoked_at": null
      }
      """.utf8
    )

    let trustedDevice = try decoder.decode(TrustedDevice.self, from: data)

    #expect(trustedDevice.id == "tdc_123")
    #expect(trustedDevice.object == "trusted_device")
    #expect(trustedDevice.platform == .iOS)
    #expect(trustedDevice.appIdentifier == "com.clerk.example")
    #expect(trustedDevice.name == "Sean's iPhone")
    #expect(trustedDevice.algorithm == .es256)
    #expect(trustedDevice.status == .active)
    #expect(trustedDevice.createdAt == Date(timeIntervalSince1970: 1_710_000_000))
    #expect(trustedDevice.updatedAt == Date(timeIntervalSince1970: 1_710_000_001))
    #expect(trustedDevice.lastUsedAt == Date(timeIntervalSince1970: 1_710_000_002))
    #expect(trustedDevice.revokedAt == nil)
  }

  @Test
  func trustedDeviceChallengeDecodesBackendShape() throws {
    let data = Data(
      """
      {
        "object": "trusted_device_challenge",
        "challenge": "challenge",
        "challenge_id": "tdch_123",
        "trusted_device_id": "tdc_123",
        "client_data": "{\\"challenge_id\\":\\"tdch_123\\"}",
        "expires_at": 1710000000000,
        "algorithm": "ES256"
      }
      """.utf8
    )

    let challenge = try decoder.decode(TrustedDeviceChallenge.self, from: data)

    #expect(challenge.object == "trusted_device_challenge")
    #expect(challenge.challenge == "challenge")
    #expect(challenge.challengeId == "tdch_123")
    #expect(challenge.trustedDeviceId == "tdc_123")
    #expect(challenge.clientData == "{\"challenge_id\":\"tdch_123\"}")
    #expect(challenge.expiresAt == Date(timeIntervalSince1970: 1_710_000_000))
    #expect(challenge.algorithm == .es256)
  }

  @Test
  func prepareEnrollmentParamsEncodeBackendKeys() throws {
    let params = TrustedDevice.PrepareEnrollmentParams(
      appIdentifier: "com.clerk.example",
      name: "Sean's iPhone",
      publicKeyJWK: "{\"kty\":\"EC\"}"
    )

    let data = try encoder.encode(params)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["platform"] as? String == "ios")
    #expect(object["app_identifier"] as? String == "com.clerk.example")
    #expect(object["name"] as? String == "Sean's iPhone")
    #expect(object["algorithm"] as? String == "ES256")
    #expect(object["public_key_jwk"] as? String == "{\"kty\":\"EC\"}")
  }
}
