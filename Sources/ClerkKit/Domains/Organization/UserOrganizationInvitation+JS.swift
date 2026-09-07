import ClerkSnapshots
import Foundation

extension UserOrganizationInvitation {
  /// Accepts the organization invitation.
  /// - Returns: The accepted ``UserOrganizationInvitation``.
  @discardableResult @MainActor
  public func accept() async throws -> UserOrganizationInvitation {
    try await Clerk.js(
      .listed(.userOrganizationInvitation, id: ClerkJSResourceID(id)),
      UserOrganizationInvitationJSCall.accept,
      as: UserOrganizationInvitation.self
    )
  }
}
