//
//  OrganizationSuggestion.swift
//  Clerk
//
//  Created by Mike Pitre on 3/14/25.
//

import FactoryKit
import Foundation

/// An interface representing an organization suggestion.
public struct OrganizationSuggestion: Codable, Equatable, Sendable, Hashable, Identifiable {

  /// An interface representing an organization suggestion.
  /// The ID of the organization suggestion.
  public let id: String

  /// The public data of the organization.
  public let publicOrganizationData: PublicOrganizationData

  /// The status of the organization suggestion.
  public let status: String

  /// The date and time when the organization suggestion was created.
  public let createdAt: Date

  /// The date and time when the organization suggestion was last updated.
  public let updatedAt: Date

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
  public struct PublicOrganizationData: Codable, Equatable, Sendable, Hashable {

    /// Whether the organization has an image.
    public let hasImage: Bool

    /// Holds the organization logo. Compatible with Clerk's Image Optimization.
    public let imageUrl: String

    /// The name of the organization.
    public let name: String

    /// The ID of the organization.
    public let id: String

    /// The slug of the organization.
    public let slug: String?

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

  /// Accepts the organization suggestion.
  /// - Returns: The accepted ``OrganizationSuggestion``.
  @discardableResult @MainActor
  public func accept() async throws -> OrganizationSuggestion {
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/organization_suggestions/\(id)/accept")
      .method(.post)
      .addClerkSessionId()
      .data(type: ClientResponse<OrganizationSuggestion>.self)
      .async()
      .response
  }

}

extension OrganizationSuggestion {

  static var mock: Self {
    .init(
      id: "1",
      publicOrganizationData: .init(
        hasImage: false,
        imageUrl: "",
        name: "name",
        id: "1",
        slug: "slug"
      ),
      status: "pending",
      createdAt: .distantPast,
      updatedAt: .now
    )
  }

}
