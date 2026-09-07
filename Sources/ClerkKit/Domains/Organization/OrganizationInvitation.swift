import ClerkSnapshots
import Foundation

public typealias OrganizationInvitation = ClerkSnapshots.OrganizationInvitation

extension OrganizationInvitation {
  public init(
    id: String,
    emailAddress: String,
    organizationId: String,
    publicMetadata: JSON,
    role: String,
    status: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.init(
      object: "organization_invitation",
      id: id,
      emailAddress: emailAddress,
      organizationId: organizationId,
      publicMetadata: publicMetadata.jsonValue,
      status: OrganizationInvitationStatus(rawValue: status),
      role: role,
      roleName: "",
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

extension OrganizationInvitationStatus {
  public var rawValue: String {
    switch self {
    case .expired:
      "expired"
    case .revoked:
      "revoked"
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
    case "expired":
      self = .expired
    case "revoked":
      self = .revoked
    case "pending":
      self = .pending
    case "accepted":
      self = .accepted
    default:
      self = .unknown(rawValue)
    }
  }
}
