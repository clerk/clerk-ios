import Foundation

extension ExternalAccount {
  /// Opens the OAuth flow using the redirect URL from this account's verification.
  ///
  /// Use after ``User/createExternalAccount(provider:redirectUrl:additionalScopes:oidcPrompts:)``
  /// or ``prepareReauthorization(additionalScopes:oidcPrompts:)`` to complete the
  /// browser-based authorization step.
  ///
  /// - Parameters:
  ///     - prefersEphemeralWebBrowserSession: A Boolean indicating whether to prefer an ephemeral web
  ///                                         browser session (default is `false`). When `true`, the session
  ///                                         does not persist cookies or other data between sessions, ensuring
  ///                                         a private browsing experience.
  @discardableResult @MainActor
  public func reauthorize(prefersEphemeralWebBrowserSession: Bool = false) async throws -> ExternalAccount {
    guard
      let redirectUrl = verification?.externalVerificationRedirectUrl,
      let url = URL(string: redirectUrl)
    else {
      throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.", localizationBundle: .module)
    }

    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )

    _ = try await authSession.start()

    try await Clerk.shared.refreshClient()
    guard let externalAccount = Clerk.shared.user?.externalAccounts.first(where: { $0.id == id }) else {
      throw ClerkClientError(message: "Something went wrong. Please try again.", localizationBundle: .module)
    }
    return externalAccount
  }
}
