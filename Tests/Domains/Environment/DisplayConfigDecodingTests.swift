@testable import ClerkKit
import Foundation
import Testing

struct DisplayConfigDecodingTests {
  private let decoder = JSONDecoder.clerkDecoder
  private let encoder = JSONEncoder.clerkEncoder

  @Test
  func showDevmodeWarningDecodesTrue() throws {
    let data = displayConfigJSON(showDevmodeWarning: true)

    let displayConfig = try decoder.decode(Clerk.Environment.DisplayConfig.self, from: data)

    #expect(displayConfig.showDevmodeWarning == true)
  }

  @Test
  func showDevmodeWarningDecodesFalse() throws {
    let data = displayConfigJSON(showDevmodeWarning: false)

    let displayConfig = try decoder.decode(Clerk.Environment.DisplayConfig.self, from: data)

    #expect(displayConfig.showDevmodeWarning == false)
  }

  @Test
  func showDevmodeWarningDefaultsFalseWhenMissing() throws {
    let data = displayConfigJSON()

    let displayConfig = try decoder.decode(Clerk.Environment.DisplayConfig.self, from: data)

    #expect(displayConfig.showDevmodeWarning == false)
  }

  @Test
  func showDevmodeWarningEncodesBackendKey() throws {
    var displayConfig = Clerk.Environment.DisplayConfig.mock
    displayConfig.showDevmodeWarning = true

    let data = try encoder.encode(displayConfig)
    let json = try #require(String(data: data, encoding: .utf8))

    #expect(json.contains("\"show_devmode_warning\":true"))
  }

  private func displayConfigJSON(showDevmodeWarning: Bool? = nil) -> Data {
    var fields = [
      "\"instance_environment_type\": \"development\"",
      "\"application_name\": \"Acme Co\"",
      "\"preferred_sign_in_strategy\": \"otp\"",
      "\"support_email\": \"support@example.com\"",
      "\"branded\": true",
      "\"logo_image_url\": \"\"",
      "\"home_url\": \"\"",
      "\"privacy_policy_url\": \"privacy\"",
      "\"terms_url\": \"terms\"",
    ]

    if let showDevmodeWarning {
      fields.append("\"show_devmode_warning\": \(showDevmodeWarning)")
    }

    return Data("{ \(fields.joined(separator: ", ")) }".utf8)
  }
}
