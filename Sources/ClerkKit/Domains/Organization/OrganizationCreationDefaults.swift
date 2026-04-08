//
//  OrganizationCreationDefaults.swift
//

import Foundation

public struct OrganizationCreationDefaults: Codable, Sendable, Equatable {
  public var advisory: Advisory?
  public var form: Form

  public struct Advisory: Codable, Sendable, Equatable {
    public var code: String
    public var severity: String
    public var meta: [String: String]
  }

  public struct Form: Codable, Sendable, Equatable {
    public var name: String
    public var slug: String
    public var logo: String?
    public var blurHash: String?
  }
}
