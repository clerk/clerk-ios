//
//  OrganizationDomain.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import Foundation

/// The model representing an organization domain.
public struct OrganizationDomain: Codable, Identifiable, Hashable, Sendable {
  /// The unique identifier for this organization domain.
  public var id: String

  /// The name for this organization domain (e.g. example.com).
  public var name: String

  /// The organization ID of the organization this domain is for.
  public var organizationId: String

  /// The enrollment mode for new users joining the organization.
  public var enrollmentMode: String

  /// The object that describes the status of the verification process of the domain.
  public var verification: Verification

  /// The email address that was used to verify this organization domain, or `nil` if not available.
  public var affiliationEmailAddress: String?

  /// The number of total pending invitations sent to emails that match the domain name.
  public var totalPendingInvitations: Int

  /// The number of total pending suggestions sent to emails that match the domain name.
  public var totalPendingSuggestions: Int

  /// The date when the organization domain was created.
  public var createdAt: Date

  /// The date when the organization domain was last updated.
  public var updatedAt: Date

  public init(
    id: String,
    name: String,
    organizationId: String,
    enrollmentMode: String,
    verification: OrganizationDomain.Verification,
    affiliationEmailAddress: String? = nil,
    totalPendingInvitations: Int,
    totalPendingSuggestions: Int,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.organizationId = organizationId
    self.enrollmentMode = enrollmentMode
    self.verification = verification
    self.affiliationEmailAddress = affiliationEmailAddress
    self.totalPendingInvitations = totalPendingInvitations
    self.totalPendingSuggestions = totalPendingSuggestions
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// The model representing the verification details of an organization domain.
  public struct Verification: Codable, Sendable, Hashable {
    /// The status of the verification process.
    public var status: String

    /// The strategy used for the verification process.
    public var strategy: String

    /// The number of attempts that have occurred to verify the domain.
    ///
    /// This value tracks how many verification attempts have been made for this domain.
    public var attempts: Int

    /// The expiration date and time of the verification.
    ///
    /// Once the expiration date has passed, the verification process may need to be restarted.
    public var expireAt: Date?

    public init(
      status: String,
      strategy: String,
      attempts: Int,
      expireAt: Date? = nil
    ) {
      self.status = status
      self.strategy = strategy
      self.attempts = attempts
      self.expireAt = expireAt
    }
  }
}

public extension OrganizationDomain {
  @MainActor
  private var organizationService: any OrganizationServiceProtocol { Clerk.shared.dependencies.organizationService }

  /// Deletes the organization domain and removes it from the organization.
  @discardableResult @MainActor
  func delete() async throws -> DeletedObject {
    try await organizationService.deleteOrganizationDomain(organizationId: organizationId, domainId: id)
  }

  /// Begins the verification process of a created organization domain.
  ///
  /// This is a required step to complete the registration of the domain under the organization.
  ///
  /// - Parameter affiliationEmailAddress: An email address affiliated with the domain name (e.g., `user@example.com`).
  /// - Returns: The unverified ``OrganizationDomain`` object.
  /// - Throws: An error if the verification process cannot be initiated.
  @discardableResult @MainActor
  func prepareAffiliationVerification(affiliationEmailAddress: String) async throws -> OrganizationDomain {
    try await organizationService.prepareOrganizationDomainAffiliationVerification(organizationId: organizationId, domainId: id, affiliationEmailAddress: affiliationEmailAddress)
  }

  /// Attempts to complete the domain verification process.
  ///
  /// This is a required step to complete the registration of a domain under an organization, as the administrator should be verified as a person affiliated with that domain.
  ///
  /// Make sure that an ``OrganizationDomain`` object already exists before calling this method by first calling ``prepareAffiliationVerification(affiliationEmailAddress:)``.
  ///
  /// - Parameter code: The one-time code sent to the user as part of this verification step.
  /// - Returns: The verified ``OrganizationDomain`` object.
  /// - Throws: An error if the verification process cannot be completed.
  @discardableResult @MainActor
  func attemptAffiliationVerification(code: String) async throws -> OrganizationDomain {
    try await organizationService.attemptOrganizationDomainAffiliationVerification(organizationId: organizationId, domainId: id, code: code)
  }
}
