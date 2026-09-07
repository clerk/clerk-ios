import ClerkSnapshots
import Foundation

extension ExternalAccount {
  /// Prepares a reauthorization for an existing external account, requesting new scopes or prompts.
  ///
  /// Calls the backend to generate a new authorization URL with the specified parameters.
  /// Call ``reauthorize(prefersEphemeralWebBrowserSession:)`` on the returned account
  /// to open the OAuth flow in a browser.
  ///
  /// - Parameters:
  ///     - redirectUrl: A custom redirect URL for the OAuth callback. When `nil`, the global
  ///                    redirect URL from ``Clerk/Options`` is used.
  ///     - additionalScopes: Additional scopes to request from the OAuth provider.
  ///     - oidcPrompts: OIDC prompt values to include in the authorization request.
  @MainActor
  public func prepareReauthorization(
    redirectUrl: String? = nil,
    additionalScopes: [String] = [],
    oidcPrompts: [OIDCPrompt] = []
  ) async throws -> ExternalAccount {
    try await Clerk.js(
      .userResource(.externalAccounts, id: ClerkJSResourceID(id)),
      ExternalAccountJSCall.reauthorize(
        ReauthorizeExternalAccountParams(
          additionalScopes: additionalScopes,
          redirectUrl: redirectUrl ?? Clerk.shared.options.redirectConfig.redirectUrl,
          oidcPrompt: oidcPrompts.serializedPrompt
        )
      ),
      as: ExternalAccount.self
    )
  }

  /// Deletes this external account.
  @discardableResult @MainActor
  public func destroy() async throws -> DeletedObject {
    try await Clerk.js(
      .userResource(.externalAccounts, id: ClerkJSResourceID(id)),
      ExternalAccountJSCall.destroy,
      as: DeletedObject.self
    )
  }
}
