@testable import ClerkKit
import Foundation
import Testing

struct FactorTests {
  @Test
  func defaultInitializerParameterRoundTripsThroughJSON() throws {
    let factor = Factor(
      strategy: .phoneCode,
      phoneNumberId: "idn_123",
      safeIdentifier: "+15555550123",
      primary: true,
      default: true
    )

    let data = try JSONEncoder.clerkEncoder.encode(factor)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["default"] as? Bool == true)
    #expect(object["phone_number_id"] as? String == "idn_123")
    #expect(object["safe_identifier"] as? String == "+15555550123")
    #expect(object["primary"] as? Bool == true)

    let decoded = try JSONDecoder.clerkDecoder.decode(Factor.self, from: data)

    #expect(decoded == factor)
    #expect(decoded.default == true)
  }

  @Test
  func trustedDeviceStrategyRoundTripsThroughJSON() throws {
    let strategy = FactorStrategy.trustedDevice

    let data = try JSONEncoder.clerkEncoder.encode(strategy)
    let rawValue = try #require(String(data: data, encoding: .utf8))

    #expect(rawValue == "\"trusted_device\"")
    #expect(try JSONDecoder.clerkDecoder.decode(FactorStrategy.self, from: data) == .trustedDevice)
  }

  @Test
  func trustedDeviceFactorRoundTripsThroughJSON() throws {
    let factor = Factor(
      strategy: .trustedDevice,
      trustedDeviceId: "tdc_123",
      safeIdentifier: "Sean's iPhone"
    )

    let data = try JSONEncoder.clerkEncoder.encode(factor)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["strategy"] as? String == "trusted_device")
    #expect(object["trusted_device_id"] as? String == "tdc_123")
    #expect(object["safe_identifier"] as? String == "Sean's iPhone")

    let decoded = try JSONDecoder.clerkDecoder.decode(Factor.self, from: data)

    #expect(decoded == factor)
    #expect(decoded.trustedDeviceId == "tdc_123")
  }
}
