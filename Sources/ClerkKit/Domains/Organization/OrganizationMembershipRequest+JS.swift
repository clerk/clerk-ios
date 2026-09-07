import ClerkSnapshots
import Foundation

extension OrganizationMembershipRequest {
  /// Accepts the request of a user to join the organization the request refers to.
  @discardableResult @MainActor
  public func accept() async throws -> OrganizationMembershipRequest {
    try await Clerk.js(
      .listed(.organizationMembershipRequest, id: ClerkJSResourceID(id)),
      OrganizationMembershipRequestJSCall.accept,
      as: OrganizationMembershipRequest.self
    )
  }

  /// Rejects the request of a user to join the organization the request refers to.
  @discardableResult @MainActor
  public func reject() async throws -> OrganizationMembershipRequest {
    try await Clerk.js(
      .listed(.organizationMembershipRequest, id: ClerkJSResourceID(id)),
      OrganizationMembershipRequestJSCall.reject,
      as: OrganizationMembershipRequest.self
    )
  }
}
