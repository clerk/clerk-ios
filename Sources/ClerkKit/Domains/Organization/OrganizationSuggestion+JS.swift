import ClerkSnapshots
import Foundation

extension OrganizationSuggestion {
  /// Accepts the organization suggestion.
  /// - Returns: The accepted ``OrganizationSuggestion``.
  @discardableResult @MainActor
  public func accept() async throws -> OrganizationSuggestion {
    try await Clerk.js(
      .listed(.organizationSuggestion, id: ClerkJSResourceID(id)),
      OrganizationSuggestionJSCall.accept,
      as: OrganizationSuggestion.self
    )
  }
}
