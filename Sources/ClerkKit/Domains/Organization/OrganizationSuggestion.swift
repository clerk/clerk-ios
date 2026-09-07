import ClerkSnapshots
import Foundation

public typealias OrganizationSuggestion = ClerkSnapshots.OrganizationSuggestion

extension OrganizationSuggestion {
  public typealias PublicOrganizationData = ClerkSnapshots.PublicOrganizationData

  public init(
    id: String,
    publicOrganizationData: PublicOrganizationData,
    status: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.init(
      object: "organization_suggestion",
      id: id,
      publicOrganizationData: publicOrganizationData,
      status: OrganizationSuggestionStatus(rawValue: status),
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

extension OrganizationSuggestionStatus {
  public var rawValue: String {
    switch self {
    case .pending:
      "pending"
    case .accepted:
      "accepted"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "pending":
      self = .pending
    case "accepted":
      self = .accepted
    default:
      self = .unknown(rawValue)
    }
  }
}

extension PublicOrganizationData {
  public init(
    hasImage: Bool,
    imageUrl: String,
    name: String,
    id: String,
    slug: String? = nil
  ) {
    self.init(id: id, name: name, slug: slug, hasImage: hasImage, imageUrl: imageUrl)
  }
}
