//
//  OrganizationCreationDefaults.swift
//

import Foundation

public struct OrganizationCreationDefaults: Codable, Hashable, Sendable {
  public var advisory: Advisory?
  public var form: Form

  public struct Advisory: Codable, Hashable, Sendable {
    public var code: String
    public var severity: String
    public var meta: [String: String]
  }

  public struct Form: Codable, Hashable, Sendable {
    public var name: String
    public var slug: String
    public var logo: String?
    public var blurHash: String?
  }
}
