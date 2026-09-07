import ClerkSnapshots
import Foundation

extension OrganizationInvitation {
  /// Revokes the invitation for the email it corresponds to.
  @discardableResult @MainActor
  public func revoke() async throws -> OrganizationInvitation {
    try await Clerk.js(
      .listed(.organizationInvitation, id: ClerkJSResourceID(id)),
      OrganizationInvitationJSCall.revoke,
      as: OrganizationInvitation.self
    )
  }
}
