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
  public let status: Status
  
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
  
  /// Represents the possible statuses of an organization suggestion.
  public enum Status: String, Codable, CodingKeyRepresentable, Sendable {
    
    /// The organization suggestion is pending review.
    case pending
    
    /// The organization suggestion has been accepted.
    case accepted
    
    /// A fallback value used when the status received from the backend is unrecognized.
    case unknown
    
    /// Initializes an `InvitationStatus` from a decoder.
    ///
    /// If the raw value from the decoder does not match any of the known cases, the `unknown` case will be used as a fallback.
    ///
    /// - Parameter decoder: The decoder to decode the raw value from.
    /// - Throws: An error if the decoding process fails.
    public init(from decoder: Decoder) throws {
      self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
    }
  }
}

extension OrganizationSuggestion {
  
  /// Accepts the organization suggestion.
  /// - Returns: The accepted OrganizationSuggestion.
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
