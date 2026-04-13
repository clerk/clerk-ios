@testable import ClerkKit
import Foundation
import Testing

struct OrganizationSettingsDecodingTests {
  private let decoder = JSONDecoder.clerkDecoder
  private let encoder = JSONEncoder.clerkEncoder

  /// Builds a full Environment JSON, optionally injecting a custom
  /// `organization_settings` value (pass `nil` to omit the key entirely).
  private func environmentJSON(organizationSettings: String? = nil) throws -> Data {
    // Encode known-good mocks for the required sibling fields.
    let authConfig = try encoder.encode(Clerk.Environment.AuthConfig.mock)
    let userSettings = try encoder.encode(Clerk.Environment.UserSettings.mock)
    let displayConfig = try encoder.encode(Clerk.Environment.DisplayConfig.mock)

    var parts = [
      "\"auth_config\": \(String(data: authConfig, encoding: .utf8)!)",
      "\"user_settings\": \(String(data: userSettings, encoding: .utf8)!)",
      "\"display_config\": \(String(data: displayConfig, encoding: .utf8)!)",
    ]
    if let organizationSettings {
      parts.append("\"organization_settings\": \(organizationSettings)")
    }

    let json = "{ \(parts.joined(separator: ", ")) }"
    return Data(json.utf8)
  }

  // MARK: - Environment level

  @Test
  func environmentDecodesWhenOrganizationSettingsKeyIsMissing() throws {
    let data = try environmentJSON(organizationSettings: nil)
    let env = try decoder.decode(Clerk.Environment.self, from: data)
    #expect(env.organizationSettings == .default)
  }

  @Test
  func environmentDecodesWhenOrganizationSettingsIsEmptyObject() throws {
    let data = try environmentJSON(organizationSettings: "{}")
    let env = try decoder.decode(Clerk.Environment.self, from: data)
    #expect(env.organizationSettings == .default)
  }

  @Test
  func environmentDecodesWhenOrganizationSettingsIsPartial() throws {
    let json = """
    {
      "enabled": true,
      "max_allowed_memberships": 5
    }
    """
    let data = try environmentJSON(organizationSettings: json)
    let env = try decoder.decode(Clerk.Environment.self, from: data)

    #expect(env.organizationSettings.enabled == true)
    #expect(env.organizationSettings.maxAllowedMemberships == 5)

    let defaults = Clerk.Environment.OrganizationSettings.default
    #expect(env.organizationSettings.forceOrganizationSelection == defaults.forceOrganizationSelection)
    #expect(env.organizationSettings.actions == defaults.actions)
    #expect(env.organizationSettings.domains == defaults.domains)
    #expect(env.organizationSettings.slug == defaults.slug)
    #expect(env.organizationSettings.organizationCreationDefaults == defaults.organizationCreationDefaults)
  }

  @Test
  func environmentDecodesWithPartialNestedOrganizationSettingsObjects() throws {
    let json = """
    {
      "enabled": true,
      "domains": {},
      "actions": {},
      "slug": {},
      "organization_creation_defaults": {}
    }
    """
    let data = try environmentJSON(organizationSettings: json)
    let env = try decoder.decode(Clerk.Environment.self, from: data)

    #expect(env.organizationSettings.enabled == true)
    #expect(env.organizationSettings.domains.enabled == false)
    #expect(env.organizationSettings.actions.adminDelete == false)
    #expect(env.organizationSettings.slug.disabled == false)
    #expect(env.organizationSettings.organizationCreationDefaults.enabled == false)
  }

  @Test
  func environmentDecodesFullOrganizationSettingsPayloadCorrectly() throws {
    let json = """
    {
      "enabled": true,
      "max_allowed_memberships": 10,
      "force_organization_selection": true,
      "actions": { "admin_delete": true },
      "domains": {
        "enabled": true,
        "enrollment_modes": ["automatic_invitation"],
        "default_role": "org:member"
      },
      "slug": { "disabled": true },
      "organization_creation_defaults": { "enabled": true }
    }
    """
    let data = try environmentJSON(organizationSettings: json)
    let env = try decoder.decode(Clerk.Environment.self, from: data)

    #expect(env.organizationSettings.enabled == true)
    #expect(env.organizationSettings.maxAllowedMemberships == 10)
    #expect(env.organizationSettings.forceOrganizationSelection == true)
    #expect(env.organizationSettings.actions.adminDelete == true)
    #expect(env.organizationSettings.domains.enabled == true)
    #expect(env.organizationSettings.domains.enrollmentModes == ["automatic_invitation"])
    #expect(env.organizationSettings.domains.defaultRole == "org:member")
    #expect(env.organizationSettings.slug.disabled == true)
    #expect(env.organizationSettings.organizationCreationDefaults.enabled == true)
  }
}
