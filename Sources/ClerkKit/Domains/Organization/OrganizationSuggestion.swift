//
//  OrganizationSuggestion.swift
//  Clerk
//
//  Created by Mike Pitre on 3/14/25.
//

import Foundation

/// An interface representing an organization suggestion.
public struct OrganizationSuggestion: Codable, Equatable, Sendable, Identifiable {
  /// An interface representing an organization suggestion.
  /// The ID of the organization suggestion.
  public var id: String

  /// The public data of the organization.
  public var publicOrganizationData: PublicOrganizationData

  /// The status of the organization suggestion.
  public var status: String

  /// The date and time when the organization suggestion was created.
  public var createdAt: Date

  /// The date and time when the organization suggestion was last updated.
  public var updatedAt: Date

  public init(
    id: String,
    publicOrganizationData: OrganizationSuggestion.PublicOrganizationData,
    status: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.publicOrganizationData = publicOrganizationData
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// The public data of the organization.
  public struct PublicOrganizationData: Codable, Equatable, Sendable {
    /// Whether the organization has an image.
    public var hasImage: Bool

    /// Holds the organization logo. Compatible with Clerk's Image Optimization.
    public var imageUrl: String

    /// The name of the organization.
    public var name: String

    /// The ID of the organization.
    public var id: String

    /// The slug of the organization.
    public var slug: String?

    public init(
      hasImage: Bool,
      imageUrl: String,
      name: String,
      id: String,
      slug: String? = nil
    ) {
      self.hasImage = hasImage
      self.imageUrl = imageUrl
      self.name = name
      self.id = id
      self.slug = slug
    }
  }
}

extension OrganizationSuggestion {
  @MainActor
  private var organizationService: any OrganizationServiceProtocol { Clerk.shared.dependencies.organizationService }

  /// Accepts the organization suggestion.
  /// - Returns: The accepted ``OrganizationSuggestion``.
  @discardableResult @MainActor
  public func accept() async throws -> OrganizationSuggestion {
    try await organizationService.acceptOrganizationSuggestion(suggestionId: id)
  }
}
