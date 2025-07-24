//
//  ExternalAccount.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import FactoryKit
import Foundation

///The `ExternalAccount` object is a model around an identification obtained by an external provider (e.g. a social provider such as Google).
///
///External account must be verified, so that you can make sure they can be assigned to their rightful owners. The `ExternalAccount` object holds all necessary state around the verification process.
public struct ExternalAccount: Codable, Identifiable, Sendable, Hashable, Equatable {

  /// The unique identifier for this external account.
  public let id: String

  /// The identification with which this external account is associated.
  public let identificationId: String

  /// The provider name e.g. google
  public let provider: String

  /// The unique ID of the user in the provider.
  public let providerUserId: String

  /// The provided email address of the user.
  public let emailAddress: String

  /// The scopes that the user has granted access to.
  public let approvedScopes: String

  /// The user's first name.
  public let firstName: String?

  /// The user's last name.
  public let lastName: String?

  /// The user's image URL.
  public let imageUrl: String?

  /// The user's username.
  public let username: String?

  /// Metadata that can be read from the Frontend API and Backend API and can be set only from the Backend API.
  public let publicMetadata: JSON

  /// A descriptive label to differentiate multiple external accounts of the same user for the same provider.
  public let label: String?

  /// An object holding information on the verification of this external account.
  public let verification: Verification?

  /// The date when the external account was created.
  public let createdAt: Date

  public init(
    id: String,
    identificationId: String,
    provider: String,
    providerUserId: String,
    emailAddress: String,
    approvedScopes: String,
    firstName: String? = nil,
    lastName: String? = nil,
    imageUrl: String? = nil,
    username: String? = nil,
    publicMetadata: JSON,
    label: String? = nil,
    verification: Verification? = nil,
    createdAt: Date = .now
  ) {
    self.id = id
    self.identificationId = identificationId
    self.provider = provider
    self.providerUserId = providerUserId
    self.emailAddress = emailAddress
    self.approvedScopes = approvedScopes
    self.firstName = firstName
    self.lastName = lastName
    self.imageUrl = imageUrl
    self.username = username
    self.publicMetadata = publicMetadata
    self.label = label
    self.verification = verification
    self.createdAt = createdAt
  }
}

extension ExternalAccount {

  /// Invokes a re-authorization flow for an existing external account.
  ///
  /// - Parameters:
  ///     - prefersEphemeralWebBrowserSession: A Boolean indicating whether to prefer an ephemeral web
  ///                                         browser session (default is `false`). When `true`, the session
  ///                                         does not persist cookies or other data between sessions, ensuring
  ///                                         a private browsing experience.
  @discardableResult @MainActor
  public func reauthorize(prefersEphemeralWebBrowserSession: Bool = false) async throws -> ExternalAccount {
    try await Container.shared.externalAccountService().reauthorize(self, prefersEphemeralWebBrowserSession)
  }

  /// Deletes this external account.
  @discardableResult @MainActor
  public func destroy() async throws -> DeletedObject {
    try await Container.shared.externalAccountService().destroy(self)
  }
}

extension ExternalAccount {

  static var mockVerified: ExternalAccount {
    .init(
      id: "1",
      identificationId: "1",
      provider: "oauth_google",
      providerUserId: "1",
      emailAddress: "user@gmail.com",
      approvedScopes: "email openid profile",
      firstName: "First",
      lastName: "Last",
      imageUrl: nil,
      username: "username",
      publicMetadata: "{}",
      label: nil,
      verification: .mockExternalAccountVerifiedVerification
    )
  }

  static var mockUnverified: ExternalAccount {
    .init(
      id: "1",
      identificationId: "1",
      provider: "oauth_google",
      providerUserId: "1",
      emailAddress: "user@gmail.com",
      approvedScopes: "email openid profile",
      firstName: "First",
      lastName: "Last",
      imageUrl: nil,
      username: "username",
      publicMetadata: "{}",
      label: nil,
      verification: .mockExternalAccountUnverifiedVerification
    )
  }

}
