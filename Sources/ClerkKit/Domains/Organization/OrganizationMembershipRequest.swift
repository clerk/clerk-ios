import ClerkSnapshots
import Foundation

public typealias OrganizationMembershipRequest = ClerkSnapshots.OrganizationMembershipRequest

extension OrganizationMembershipRequest {
  public init(
    id: String,
    organizationId: String,
    status: String,
    publicUserData: PublicUserData? = nil,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.init(
      object: "organization_membership_request",
      id: id,
      organizationId: organizationId,
      status: OrganizationInvitationStatus(rawValue: status),
      publicUserData: publicUserData ?? PublicUserData(imageUrl: "", hasImage: false, identifier: ""),
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
