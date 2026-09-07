import ClerkSnapshots
import Foundation

public typealias OrganizationDomain = ClerkSnapshots.OrganizationDomain

extension OrganizationDomain: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

extension OrganizationDomain {
  public typealias EnrollmentMode = OrganizationDomainEnrollmentMode
  public typealias Verification = OrganizationDomainVerification

  public var enrollmentModeType: EnrollmentMode {
    enrollmentMode
  }

  public var isVerified: Bool {
    verification?.status == .verified
  }

  public init(
    id: String,
    name: String,
    organizationId: String,
    enrollmentMode: String,
    verification: OrganizationDomainVerification? = nil,
    affiliationEmailAddress: String? = nil,
    totalPendingInvitations: Int,
    totalPendingSuggestions: Int,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.init(
      object: "organization_domain",
      id: id,
      name: name,
      organizationId: organizationId,
      enrollmentMode: OrganizationDomainEnrollmentMode(rawValue: enrollmentMode),
      verification: verification,
      affiliationEmailAddress: affiliationEmailAddress,
      createdAt: createdAt,
      updatedAt: updatedAt,
      totalPendingInvitations: totalPendingInvitations,
      totalPendingSuggestions: totalPendingSuggestions
    )
  }

  @discardableResult @MainActor
  public func sendEmailCode(affiliationEmailAddress: String) async throws -> OrganizationDomain {
    try await prepareAffiliationVerification(affiliationEmailAddress: affiliationEmailAddress)
  }

  @discardableResult @MainActor
  public func verifyCode(_ code: String) async throws -> OrganizationDomain {
    try await attemptAffiliationVerification(code: code)
  }
}

extension OrganizationDomainVerification {
  public init(
    status: String,
    strategy: String,
    attempts: Int,
    expireAt: Date? = nil
  ) {
    self.init(
      status: OrganizationDomainVerificationStatus(rawValue: status),
      strategy: strategy,
      attempts: attempts,
      expiresAt: expireAt ?? Date(timeIntervalSince1970: 0)
    )
  }
}

extension OrganizationDomainEnrollmentMode {
  public var rawValue: String {
    switch self {
    case .enterpriseSso:
      "enterprise_sso"
    case .manualInvitation:
      "manual_invitation"
    case .automaticInvitation:
      "automatic_invitation"
    case .automaticSuggestion:
      "automatic_suggestion"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "enterprise_sso":
      self = .enterpriseSso
    case "manual_invitation":
      self = .manualInvitation
    case "automatic_invitation":
      self = .automaticInvitation
    case "automatic_suggestion":
      self = .automaticSuggestion
    default:
      self = .unknown(rawValue)
    }
  }
}

extension OrganizationDomainVerificationStatus {
  public var rawValue: String {
    switch self {
    case .expired:
      "expired"
    case .unverified:
      "unverified"
    case .verified:
      "verified"
    case .failed:
      "failed"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "expired":
      self = .expired
    case "unverified":
      self = .unverified
    case "verified":
      self = .verified
    case "failed":
      self = .failed
    default:
      self = .unknown(rawValue)
    }
  }
}
