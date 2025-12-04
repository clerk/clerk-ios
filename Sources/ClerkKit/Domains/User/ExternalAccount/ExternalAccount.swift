//
//  ExternalAccount.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import Foundation

/// The `ExternalAccount` object is a model around an identification obtained by an external provider (e.g. a social provider such as Google).
///
/// External account must be verified, so that you can make sure they can be assigned to their rightful owners. The `ExternalAccount` object holds all necessary state around the verification process.
public struct ExternalAccount: Codable, Identifiable, Sendable, Equatable {
  /// The unique identifier for this external account.
  public var id: String

  /// The identification with which this external account is associated.
  public var identificationId: String

  /// The provider name e.g. google
  public var provider: String

  /// The unique ID of the user in the provider.
  public var providerUserId: String

  /// The provided email address of the user.
  public var emailAddress: String

  /// The scopes that the user has granted access to.
  public var approvedScopes: String

  /// The user's first name.
  public var firstName: String?

  /// The user's last name.
  public var lastName: String?

  /// The user's image URL.
  public var imageUrl: String?

  /// The user's username.
  public var username: String?

  /// Metadata that can be read from the Frontend API and Backend API and can be set only from the Backend API.
  public var publicMetadata: JSON

  /// A descriptive label to differentiate multiple external accounts of the same user for the same provider.
  public var label: String?

  /// An object holding information on the verification of this external account.
  public var verification: Verification?

  /// The date when the external account was created.
  public var createdAt: Date

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

public extension ExternalAccount {
  @MainActor
  private var externalAccountService: any ExternalAccountServiceProtocol { Clerk.shared.dependencies.externalAccountService }

  /// Invokes a re-authorization flow for an existing external account.
  ///
  /// - Parameters:
  ///     - prefersEphemeralWebBrowserSession: A Boolean indicating whether to prefer an ephemeral web
  ///                                         browser session (default is `false`). When `true`, the session
  ///                                         does not persist cookies or other data between sessions, ensuring
  ///                                         a private browsing experience.
  @discardableResult @MainActor
  func reauthorize(prefersEphemeralWebBrowserSession: Bool = false) async throws -> ExternalAccount {
    guard
      let redirectUrl = verification?.externalVerificationRedirectUrl,
      let url = URL(string: redirectUrl)
    else {
      throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
    }

    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )

    _ = try await authSession.start()

    try await Client.get()
    guard let externalAccount = Clerk.shared.user?.externalAccounts.first(where: { $0.id == id }) else {
      throw ClerkClientError(message: "Something went wrong. Please try again.")
    }
    return externalAccount
  }

  /// Deletes this external account.
  @discardableResult @MainActor
  func destroy() async throws -> DeletedObject {
    try await externalAccountService.destroy(id)
  }
}
