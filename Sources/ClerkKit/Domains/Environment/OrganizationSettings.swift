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
  }
}
