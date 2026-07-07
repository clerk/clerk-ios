@testable import ClerkKit
import Foundation
import Testing

struct ForceUpdateDecodingTests {
  private let decoder = JSONDecoder.clerkDecoder
  private let encoder = JSONEncoder.clerkEncoder

  private enum TestError: Error {
    case invalidUTF8
  }

  @Test
  func forceUpdateDefaultsToEmptyWhenMissing() throws {
    let data = try environmentJSON()

    let environment = try decoder.decode(Clerk.Environment.self, from: data)

    #expect(environment.forceUpdate == .empty)
  }

  @Test
  func forceUpdateDecodesResolvedRequirement() throws {
    let data = try environmentJSON(
      forceUpdate: """
      "force_update": {
        "required": true,
        "minimum_app_version": "1.2.3",
        "app_store_url": "https://apps.apple.com/app/id123456789"
      }
      """
    )

    let environment = try decoder.decode(Clerk.Environment.self, from: data)

    #expect(environment.forceUpdate.required)
    #expect(environment.forceUpdate.minimumAppVersion == "1.2.3")
    #expect(
      environment.forceUpdate.appStoreURL?.absoluteString
        == "https://apps.apple.com/app/id123456789"
    )
  }

  @Test
  func forceUpdateDecodesNotRequiredResponse() throws {
    let data = try environmentJSON(
      forceUpdate: """
      "force_update": {
        "required": false
      }
      """
    )

    let environment = try decoder.decode(Clerk.Environment.self, from: data)

    #expect(environment.forceUpdate == .empty)
  }

  private func environmentJSON(forceUpdate: String? = nil) throws -> Data {
    let authConfig = try encoder.encode(Clerk.Environment.AuthConfig.mock)
    let userSettings = try encoder.encode(Clerk.Environment.UserSettings.mock)
    let displayConfig = try encoder.encode(Clerk.Environment.DisplayConfig.mock)
    guard
      let authConfigString = String(data: authConfig, encoding: .utf8),
      let userSettingsString = String(data: userSettings, encoding: .utf8),
      let displayConfigString = String(data: displayConfig, encoding: .utf8)
    else {
      throw TestError.invalidUTF8
    }

    var fields = [
      "\"auth_config\": \(authConfigString)",
      "\"user_settings\": \(userSettingsString)",
      "\"display_config\": \(displayConfigString)",
    ]

    if let forceUpdate {
      fields.append(forceUpdate)
    }

    return Data("{ \(fields.joined(separator: ", ")) }".utf8)
  }
}
