//
//  Organizations+Domains.swift
//  Clerk
//

import Foundation

extension Organizations {
  @discardableResult
  func createDomain(
    for organization: Organization,
    domainName: String
  ) async throws -> OrganizationDomain {
    try await organizationService.createOrganizationDomain(
      organizationId: organization.id,
      domainName: domainName,
      sessionId: clerk.session?.id
    )
  }

  func getDomains(
    for organization: Organization,
    page: Int = 1,
    pageSize: Int = 20,
    enrollmentMode: String? = nil
  ) async throws -> ClerkPaginatedResponse<OrganizationDomain> {
    try await organizationService.getOrganizationDomains(
      organizationId: organization.id,
      initialPage: offset(forPage: page, pageSize: pageSize),
      pageSize: pageSize,
      enrollmentMode: enrollmentMode,
      sessionId: clerk.session?.id
    )
  }

  func getDomain(
    for organization: Organization,
    domainId: String
  ) async throws -> OrganizationDomain {
    try await organizationService.getOrganizationDomain(
      organizationId: organization.id,
      domainId: domainId,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func delete(_ domain: OrganizationDomain) async throws -> DeletedObject {
    try await organizationService.deleteOrganizationDomain(
      organizationId: domain.organizationId,
      domainId: domain.id,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func sendEmailCode(
    for domain: OrganizationDomain,
    affiliationEmailAddress: String
  ) async throws -> OrganizationDomain {
    try await organizationService.prepareOrganizationDomainAffiliationVerification(
      organizationId: domain.organizationId,
      domainId: domain.id,
      affiliationEmailAddress: affiliationEmailAddress,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func verifyCode(
    _ code: String,
    for domain: OrganizationDomain
  ) async throws -> OrganizationDomain {
    try await organizationService.attemptOrganizationDomainAffiliationVerification(
      organizationId: domain.organizationId,
      domainId: domain.id,
      code: code,
      sessionId: clerk.session?.id
    )
  }
}
