import ClerkSnapshots
import Foundation

public typealias UserOrganizationInvitation = ClerkSnapshots.UserOrganizationInvitation

extension UserOrganizationInvitation {
  public typealias PublicOrganizationData = ClerkSnapshots.PublicOrganizationData

  public init(
    id: String,
    emailAddress: String,
    publicOrganizationData: PublicOrganizationData,
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
      publicOrganizationData: publicOrganizationData,
      publicMetadata: publicMetadata.jsonValue,
      status: OrganizationInvitationStatus(rawValue: status),
      role: role,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
