//
//  OrganizationSuggestion.swift
//  Clerk
//
//  Created by Mike Pitre on 3/14/25.
//

import Factory
import Foundation
import Get

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
  }
}

extension OrganizationSuggestion {
  
  /// Accepts the organization suggestion.
  /// - Returns: The accepted ``OrganizationSuggestion``.
  @discardableResult @MainActor
  public func accept() async throws -> OrganizationSuggestion {
    let request = Request<ClientResponse<OrganizationSuggestion>>(
      path: "/v1/me/organization_suggestions/\(id)/accept",
      method: .post,
      query: [
        ("_clerk_session_id", Clerk.shared.session?.id)
      ].filter { $1 != nil }
    )
    return try await Container.shared.apiClient().send(request).value.response
  }
  
}
