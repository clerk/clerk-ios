//
//  Feature.swift
//  Clerk
//

import Foundation

public struct Feature: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var name: String
  public var description: String?
  public var slug: String
  public var avatarUrl: String?

  public init(
    id: String,
    name: String,
    description: String? = nil,
    slug: String,
    avatarUrl: String? = nil
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.slug = slug
    self.avatarUrl = avatarUrl
  }
}
