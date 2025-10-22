//
//  OrganizationDomain.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import FactoryKit
import Foundation

/// The model representing an organization domain.
public struct OrganizationDomain: Codable, Identifiable, Hashable, Sendable {

    /// The unique identifier for this organization domain.
    public let id: String

    /// The name for this organization domain (e.g. example.com).
    public let name: String

    /// The organization ID of the organization this domain is for.
    public let organizationId: String

    /// The enrollment mode for new users joining the organization.
    public let enrollmentMode: String

    /// The object that describes the status of the verification process of the domain.
    public let verification: Verification

    /// The email address that was used to verify this organization domain, or `nil` if not available.
    public let affiliationEmailAddress: String?

    /// The number of total pending invitations sent to emails that match the domain name.
    public let totalPendingInvitations: Int

    /// The number of total pending suggestions sent to emails that match the domain name.
    public let totalPendingSuggestions: Int

    /// The date when the organization domain was created.
    public let createdAt: Date

    /// The date when the organization domain was last updated.
    public let updatedAt: Date

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
        public let status: String

        /// The strategy used for the verification process.
        public let strategy: String

        /// The number of attempts that have occurred to verify the domain.
        ///
        /// This value tracks how many verification attempts have been made for this domain.
        public let attempts: Int

        /// The expiration date and time of the verification.
        ///
        /// Once the expiration date has passed, the verification process may need to be restarted.
        public let expireAt: Date?

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

extension OrganizationDomain {

    /// Deletes the organization domain and removes it from the organization.
    @discardableResult @MainActor
    public func delete() async throws -> DeletedObject {
        try await Container.shared.organizationService().deleteOrganizationDomain(organizationId, id)
    }

    /// Begins the verification process of a created organization domain.
    ///
    /// This is a required step to complete the registration of the domain under the organization.
    ///
    /// - Parameter affiliationEmailAddress: An email address affiliated with the domain name (e.g., `user@example.com`).
    /// - Returns: The unverified ``OrganizationDomain`` object.
    /// - Throws: An error if the verification process cannot be initiated.
    @discardableResult @MainActor
    public func prepareAffiliationVerification(affiliationEmailAddress: String) async throws -> OrganizationDomain {
        try await Container.shared.organizationService().prepareOrganizationDomainAffiliationVerification(organizationId, id, affiliationEmailAddress)
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
    public func attemptAffiliationVerification(code: String) async throws -> OrganizationDomain {
        try await Container.shared.organizationService().attemptOrganizationDomainAffiliationVerification(organizationId, id, code)
    }

}

extension OrganizationDomain {

    static var mock: Self {
        .init(
            id: "1",
            name: "name",
            organizationId: "1",
            enrollmentMode: "enrollment_mode",
            verification: .init(
                status: "status",
                strategy: "strategy",
                attempts: 1,
                expireAt: .distantFuture
            ),
            affiliationEmailAddress: nil,
            totalPendingInvitations: 3,
            totalPendingSuggestions: 3,
            createdAt: .distantPast,
            updatedAt: .now
        )
    }

}
