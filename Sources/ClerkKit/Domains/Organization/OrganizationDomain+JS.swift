import ClerkSnapshots
import Foundation

extension OrganizationDomain {
  /// Deletes the organization domain and removes it from the organization.
  @discardableResult @MainActor
  public func delete() async throws -> DeletedObject {
    try await Clerk.js(
      .listed(.organizationDomain, id: ClerkJSResourceID(id)),
      OrganizationDomainJSCall.delete,
      as: DeletedObject.self
    )
  }

  /// Prepares affiliation verification for this organization domain by sending a verification email.
  ///
  /// This is a required step to complete the registration of the domain under the organization.
  ///
  /// - Parameter affiliationEmailAddress: An email address affiliated with the domain name (e.g., `user@example.com`).
  /// - Returns: The unverified ``OrganizationDomain`` object.
  /// - Throws: An error if the verification process cannot be initiated.
  @discardableResult @MainActor
  public func prepareAffiliationVerification(affiliationEmailAddress: String) async throws -> OrganizationDomain {
    try await Clerk.js(
      .listed(.organizationDomain, id: ClerkJSResourceID(id)),
      OrganizationDomainJSCall.prepareAffiliationVerification(
        PrepareAffiliationVerificationParams(affiliationEmailAddress: affiliationEmailAddress)
      ),
      as: OrganizationDomain.self
    )
  }

  /// Attempts to verify the affiliation of this organization domain using a verification code.
  ///
  /// This is a required step to complete the registration of a domain under an organization, as the administrator should be verified as a person affiliated with that domain.
  ///
  /// Affiliation verification must be prepared for this domain before calling this method. Call ``prepareAffiliationVerification(affiliationEmailAddress:)`` first to issue a verification code.
  ///
  /// - Parameter code: The one-time code sent to the user as part of this verification step.
  /// - Returns: The verified ``OrganizationDomain`` object.
  /// - Throws: An error if the verification process cannot be completed.
  @discardableResult @MainActor
  public func attemptAffiliationVerification(code: String) async throws -> OrganizationDomain {
    try await Clerk.js(
      .listed(.organizationDomain, id: ClerkJSResourceID(id)),
      OrganizationDomainJSCall.attemptAffiliationVerification(
        AttemptAffiliationVerificationParams(code: code)
      ),
      as: OrganizationDomain.self
    )
  }

  /// Updates the enrollment mode for this organization domain.
  ///
  /// - Parameters:
  ///   - enrollmentMode: The enrollment mode to apply.
  ///   - deletePending: Whether pending invitations or suggestions for the previous mode should be deleted.
  /// - Returns: The updated ``OrganizationDomain`` object.
  @discardableResult @MainActor
  public func updateEnrollmentMode(
    _ enrollmentMode: EnrollmentMode,
    deletePending: Bool? = nil
  ) async throws -> OrganizationDomain {
    try await Clerk.js(
      .listed(.organizationDomain, id: ClerkJSResourceID(id)),
      OrganizationDomainJSCall.updateEnrollmentMode(
        UpdateEnrollmentModeParams(
          enrollmentMode: enrollmentMode.jsEnrollmentMode,
          deletePending: deletePending
        )
      ),
      as: OrganizationDomain.self
    )
  }
}

extension OrganizationDomain.EnrollmentMode {
  fileprivate var jsEnrollmentMode: GetDomainsParamsEnrollmentMode {
    switch self {
    case .manualInvitation:
      .manualInvitation
    case .automaticInvitation:
      .automaticInvitation
    case .automaticSuggestion:
      .automaticSuggestion
    case .unknown(let raw):
      .unknown(raw)
    }
  }
}
