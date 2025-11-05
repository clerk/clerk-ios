//
//  EnterpriseAccount.swift
//  Clerk
//
//  Created by Mike Pitre on 1/10/25.
//

import Foundation

/// A model representing an enterprise account.
///
/// `EnterpriseAccount` encapsulates the details of a user's enterprise account.
public struct EnterpriseAccount: Codable, Hashable, Equatable, Sendable {
  // MARK: - Properties

  /// The unique identifier for the enterprise account.
  public let id: String

  /// The type of object, typically a string identifier indicating the object type.
  public let object: String

  /// The authentication protocol used (e.g., SAML, OpenID).
  public let `protocol`: String

  /// The name of the provider (e.g., Okta, Google).
  public let provider: String

  /// A flag indicating whether the enterprise account is active.
  public let active: Bool

  /// The email address associated with the enterprise account.
  public let emailAddress: String

  /// The first name of the account holder, if available.
  public let firstName: String?

  /// The last name of the account holder, if available.
  public let lastName: String?

  /// The unique user identifier assigned by the provider, if available.
  public let providerUserId: String?

  /// Public metadata associated with the enterprise account.
  public let publicMetadata: JSON

  /// Verification information for the enterprise account, if available.
  public let verification: Verification?

  /// Details about the enterprise connection associated with this account.
  public let enterpriseConnection: EnterpriseConnection

  public init(
    id: String,
    object: String,
    protocol: String,
    provider: String,
    active: Bool,
    emailAddress: String,
    firstName: String? = nil,
    lastName: String? = nil,
    providerUserId: String? = nil,
    publicMetadata: JSON,
    verification: Verification? = nil,
    enterpriseConnection: EnterpriseAccount.EnterpriseConnection
  ) {
    self.id = id
    self.object = object
    self.protocol = `protocol`
    self.provider = provider
    self.active = active
    self.emailAddress = emailAddress
    self.firstName = firstName
    self.lastName = lastName
    self.providerUserId = providerUserId
    self.publicMetadata = publicMetadata
    self.verification = verification
    self.enterpriseConnection = enterpriseConnection
  }

  /// A model representing the connection details for an enterprise account.
  ///
  /// `EnterpriseConnection` contains the configuration and metadata for the connection
  /// between the enterprise account and the identity provider.
  public struct EnterpriseConnection: Codable, Hashable, Equatable, Sendable {
    /// The unique identifier for the enterprise connection.
    public let id: String

    /// The authentication protocol used (e.g., SAML, OpenID).
    public let `protocol`: String

    /// The name of the provider (e.g., Okta, Google Workspace).
    public let provider: String

    /// The display name of the enterprise connection.
    public let name: String

    /// The public URL of the provider's logo.
    public let logoPublicUrl: String

    /// The domain associated with the enterprise connection (e.g., example.com).
    public let domain: String

    /// A flag indicating whether the enterprise connection is active.
    public let active: Bool

    /// A flag indicating whether user attributes are synchronized with the provider.
    public let syncUserAttributes: Bool

    /// A flag indicating whether additional user identifications are disabled for this connection.
    public let disableAdditionalIdentifications: Bool

    /// The date and time when the enterprise connection was created.
    public let createdAt: Date

    /// The date and time when the enterprise connection was last updated.
    public let updatedAt: Date

    /// A flag indicating whether subdomains are allowed for the enterprise connection.
    public let allowSubdomains: Bool

    /// A flag indicating whether IDP-initiated flows are allowed.
    public let allowIdpInitiated: Bool

    public init(
      id: String,
      protocol: String,
      provider: String,
      name: String,
      logoPublicUrl: String,
      domain: String,
      active: Bool,
      syncUserAttributes: Bool,
      disableAdditionalIdentifications: Bool,
      createdAt: Date,
      updatedAt: Date,
      allowSubdomains: Bool,
      allowIdpInitiated: Bool
    ) {
      self.id = id
      self.protocol = `protocol`
      self.provider = provider
      self.name = name
      self.logoPublicUrl = logoPublicUrl
      self.domain = domain
      self.active = active
      self.syncUserAttributes = syncUserAttributes
      self.disableAdditionalIdentifications = disableAdditionalIdentifications
      self.createdAt = createdAt
      self.updatedAt = updatedAt
      self.allowSubdomains = allowSubdomains
      self.allowIdpInitiated = allowIdpInitiated
    }
  }
}
