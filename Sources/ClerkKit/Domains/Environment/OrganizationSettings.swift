//
//  OrganizationSettings.swift
//

import Foundation

extension Clerk.Environment {
  public struct OrganizationSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var maxAllowedMemberships: Int
    public var forceOrganizationSelection: Bool
    public var actions: Actions
    public var domains: Domains
    public var slug: Slug
    public var organizationCreationDefaults: CreationDefaults

    public struct Actions: Codable, Equatable, Sendable {
      public var adminDelete: Bool
    }

    public struct Domains: Codable, Equatable, Sendable {
      public var enabled: Bool
      public var enrollmentModes: [String]
      public var defaultRole: String?
    }

    public struct Slug: Codable, Equatable, Sendable {
      public var disabled: Bool
    }

    public struct CreationDefaults: Codable, Equatable, Sendable {
      public var enabled: Bool
    }

    /// Sensible defaults when organization settings are absent from a decoded payload.
    /// Values mirror the JS SDK defaults in OrganizationSettings.ts.
    public static let `default` = OrganizationSettings(
      enabled: false,
      maxAllowedMemberships: 1,
      forceOrganizationSelection: false,
      actions: Actions(adminDelete: false),
      domains: Domains(enabled: false, enrollmentModes: [], defaultRole: nil),
      slug: Slug(disabled: false),
      organizationCreationDefaults: CreationDefaults(enabled: false)
    )
  }
}

// MARK: - Resilient Decodable conformances

extension Clerk.Environment.OrganizationSettings {
  public init(from decoder: Decoder) throws {
    let defaults = Self.default
    let container = try decoder.container(keyedBy: CodingKeys.self)
    enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? defaults.enabled
    maxAllowedMemberships = try container.decodeIfPresent(Int.self, forKey: .maxAllowedMemberships) ?? defaults.maxAllowedMemberships
    forceOrganizationSelection = try container.decodeIfPresent(Bool.self, forKey: .forceOrganizationSelection) ?? defaults.forceOrganizationSelection
    actions = try container.decodeIfPresent(Actions.self, forKey: .actions) ?? defaults.actions
    domains = try container.decodeIfPresent(Domains.self, forKey: .domains) ?? defaults.domains
    slug = try container.decodeIfPresent(Slug.self, forKey: .slug) ?? defaults.slug
    organizationCreationDefaults = try container.decodeIfPresent(CreationDefaults.self, forKey: .organizationCreationDefaults) ?? defaults.organizationCreationDefaults
  }
}

extension Clerk.Environment.OrganizationSettings.Actions {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    adminDelete = try container.decodeIfPresent(Bool.self, forKey: .adminDelete) ?? false
  }
}

extension Clerk.Environment.OrganizationSettings.Domains {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
    enrollmentModes = try container.decodeIfPresent([String].self, forKey: .enrollmentModes) ?? []
    defaultRole = try container.decodeIfPresent(String.self, forKey: .defaultRole)
  }
}

extension Clerk.Environment.OrganizationSettings.Slug {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled) ?? false
  }
}

extension Clerk.Environment.OrganizationSettings.CreationDefaults {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
  }
}
