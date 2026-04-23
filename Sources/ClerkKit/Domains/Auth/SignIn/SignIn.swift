//
//  SignIn.swift
//

// swiftlint:disable file_length

import AuthenticationServices
import Foundation

/// The `SignIn` object holds the state of the current sign-in process and provides helper methods
/// to manage verification and session creation.
public struct SignIn: Codable, Sendable, Equatable {
  /// Unique identifier for this sign in.
  public var id: String

  /// The status of the current sign-in.
  ///
  /// See ``SignIn/Status-swift.enum`` for supported values.
  public var status: Status

  /// Array of all the authentication identifiers that are supported for this sign in.
  public var supportedIdentifiers: [Identifier]?

  /// The authentication identifier value for the current sign-in.
  public var identifier: String?

  /// Array of the first factors that are supported in the current sign-in.
  ///
  ///  Each factor contains information about the verification strategy that can be used. See the `SignInFirstFactor` type reference for more information.
  public var supportedFirstFactors: [Factor]?

  /// Array of the second factors that are supported in the current sign-in.
  ///
  /// Each factor contains information about the verification strategy that can be used. This property is populated only when the first factor is verified. See the `SignInSecondFactor` type reference for more information.
  public var supportedSecondFactors: [Factor]?

  /// The state of the verification process for the selected first factor.
  ///
  /// Initially, this property contains an empty verification object, since there is no first factor selected. You need to call the `prepareFirstFactor` method in order to start the verification process.
  public var firstFactorVerification: Verification?

  /// The state of the verification process for the selected second factor.
  ///
  /// Initially, this property contains an empty verification object, since there is no second factor selected. For the `phone_code` strategy, you need to call the `prepareSecondFactor` method in order to start the verification process. For the `totp` strategy, you can directly attempt.
  public var secondFactorVerification: Verification?

  /// An object containing information about the user of the current sign-in.
  ///
  /// This property is populated only once an identifier is given to the SignIn object.
  public var userData: UserData?

  /// The identifier of the session that was created upon completion of the current sign-in.
  ///
  /// The value of this property is `nil` if the sign-in status is not `complete`.
  public var createdSessionId: String?

  public init(
    id: String,
    status: SignIn.Status,
    supportedIdentifiers: [SignIn.Identifier]? = nil,
    identifier: String? = nil,
    supportedFirstFactors: [Factor]? = nil,
    supportedSecondFactors: [Factor]? = nil,
    firstFactorVerification: Verification? = nil,
    secondFactorVerification: Verification? = nil,
    userData: SignIn.UserData? = nil,
    createdSessionId: String? = nil
  ) {
    self.id = id
    self.status = status
    self.supportedIdentifiers = supportedIdentifiers
    self.identifier = identifier
    self.supportedFirstFactors = supportedFirstFactors
    self.supportedSecondFactors = supportedSecondFactors
    self.firstFactorVerification = firstFactorVerification
    self.secondFactorVerification = secondFactorVerification
    self.userData = userData
    self.createdSessionId = createdSessionId
  }
}

extension SignIn {
  // MARK: - First Factor Verification

  /// Sends a verification code to the specified email address.
  ///
  /// - Parameter emailAddressId: Optional email address ID. If not provided, uses the identifying first factor.
  /// - Returns: An updated `SignIn` object with the verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendEmailCode(emailAddressId: String? = nil) async throws -> SignIn {
    try await Clerk.shared.auth.sendEmailCode(for: self, emailAddressId: emailAddressId)
  }

  /// Sends a verification code to the specified phone number.
  ///
  /// - Parameter phoneNumberId: Optional phone number ID. If not provided, uses the identifying first factor.
  /// - Returns: An updated `SignIn` object with the verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendPhoneCode(phoneNumberId: String? = nil) async throws -> SignIn {
    try await Clerk.shared.auth.sendPhoneCode(for: self, phoneNumberId: phoneNumberId)
  }

  /// Verifies the code entered by the user.
  ///
  /// The verification strategy is inferred from the current `firstFactorVerification` state.
  ///
  /// - Parameter code: The verification code entered by the user.
  /// - Returns: An updated `SignIn` object reflecting the verification result.
  /// - Throws: An error if verification fails.
  @discardableResult
  @MainActor
  public func verifyCode(_ code: String) async throws -> SignIn {
    try await Clerk.shared.auth.verifyCode(code, for: self)
  }

  /// Authenticates with the user's password.
  ///
  /// - Parameter password: The user's password.
  /// - Returns: An updated `SignIn` object reflecting the authentication result.
  /// - Throws: An error if password authentication fails.
  @discardableResult
  @MainActor
  public func authenticateWithPassword(_ password: String) async throws -> SignIn {
    try await Clerk.shared.auth.authenticateWithPassword(password, for: self)
  }

  #if !os(tvOS) && !os(watchOS)
  /// Completes enterprise SSO after your app receives the callback URL.
  ///
  /// This pairs with ``Auth/startEnterpriseSSO(emailAddress:redirectUrl:)`` when your app handles browser presentation itself.
  ///
  /// - Parameters:
  ///   - callbackURL: The callback URL your app received after the user completed enterprise SSO.
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if completing enterprise SSO fails.
  @discardableResult
  @MainActor
  public func completeEnterpriseSSO(
    callbackURL: URL,
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    try await Clerk.shared.auth.completeEnterpriseSSO(
      for: self,
      callbackURL: callbackURL,
      transferable: transferable
    )
  }
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Authenticates with an ID token from a provider (e.g., Sign in with Apple).
  ///
  /// This method attempts first factor authentication using an ID token directly,
  /// without requiring a prepare step. This is useful for native authentication flows
  /// where you already have an ID token from the provider.
  ///
  /// - Parameters:
  ///   - idToken: The ID token from the provider.
  ///   - provider: The ID token provider (e.g., `.apple`).
  /// - Returns: An updated `SignIn` object reflecting the authentication result.
  /// - Throws: An error if authentication fails.
  @discardableResult
  @MainActor
  public func authenticateWithIdToken(_ idToken: String, provider: IDTokenProvider) async throws -> SignIn {
    try await Clerk.shared.auth.authenticateWithIdToken(idToken, provider: provider, for: self)
  }

  /// Authenticates with Apple using Sign in with Apple.
  ///
  /// This method handles the entire Sign in with Apple flow for an existing sign-in, including:
  /// - Requesting Apple ID credentials
  /// - Extracting the ID token
  /// - Attempting authentication with the existing sign-in
  /// - Handling the transfer flow if needed
  ///
  /// - Parameters:
  ///   - requestedScopes: The scopes to request from Apple (defaults to `[.email, .fullName]`).
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the authentication fails.
  @discardableResult
  @MainActor
  public func authenticateWithApple(
    requestedScopes: [ASAuthorization.Scope] = [.email, .fullName],
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    try await Clerk.shared.auth.authenticateWithApple(
      for: self,
      requestedScopes: requestedScopes,
      transferable: transferable
    )
  }
  #endif

  // MARK: - Second Factor Verification (MFA)

  /// Sends an MFA code to the phone number.
  ///
  /// - Parameter phoneNumberId: Optional phone number ID. If not provided, uses the identifying second factor.
  /// - Returns: An updated `SignIn` object with the MFA verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendMfaPhoneCode(phoneNumberId: String? = nil) async throws -> SignIn {
    try await Clerk.shared.auth.sendMfaPhoneCode(for: self, phoneNumberId: phoneNumberId)
  }

  /// Sends an MFA code to the email address.
  ///
  /// - Parameter emailAddressId: Optional email address ID. If not provided, uses the identifying second factor.
  /// - Returns: An updated `SignIn` object with the MFA verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendMfaEmailCode(emailAddressId: String? = nil) async throws -> SignIn {
    try await Clerk.shared.auth.sendMfaEmailCode(for: self, emailAddressId: emailAddressId)
  }

  /// Verifies the MFA code with the specified type.
  ///
  /// - Parameters:
  ///   - code: The MFA code entered by the user.
  ///   - type: The type of MFA verification (`.phoneCode`, `.emailCode`, `.totp`, or `.backupCode`).
  /// - Returns: An updated `SignIn` object reflecting the verification result.
  /// - Throws: An error if verification fails.
  @discardableResult
  @MainActor
  public func verifyMfaCode(_ code: String, type: MfaType) async throws -> SignIn {
    try await Clerk.shared.auth.verifyMfaCode(code, type: type, for: self)
  }

  // MARK: - Password Reset

  /// Sends a password reset code to the specified email address.
  ///
  /// - Parameter emailAddressId: Optional email address ID. If not provided, uses the identifying first factor.
  /// - Returns: An updated `SignIn` object with the password reset process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendResetPasswordEmailCode(emailAddressId: String? = nil) async throws -> SignIn {
    try await Clerk.shared.auth.sendResetPasswordEmailCode(for: self, emailAddressId: emailAddressId)
  }

  /// Sends a password reset code to the specified phone number.
  ///
  /// - Parameter phoneNumberId: Optional phone number ID. If not provided, uses the identifying first factor.
  /// - Returns: An updated `SignIn` object with the password reset process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendResetPasswordPhoneCode(phoneNumberId: String? = nil) async throws -> SignIn {
    try await Clerk.shared.auth.sendResetPasswordPhoneCode(for: self, phoneNumberId: phoneNumberId)
  }

  /// Resets the user's password after verification.
  ///
  /// - Parameters:
  ///   - newPassword: The new password to set.
  ///   - signOutOfOtherSessions: Whether to sign out of all other active sessions (default is `false`).
  /// - Returns: An updated `SignIn` object reflecting the password reset result.
  /// - Throws: An error if password reset fails.
  @discardableResult
  @MainActor
  public func resetPassword(newPassword: String, signOutOfOtherSessions: Bool = false) async throws -> SignIn {
    try await Clerk.shared.auth.resetPassword(
      for: self,
      newPassword: newPassword,
      signOutOfOtherSessions: signOutOfOtherSessions
    )
  }

  // MARK: - Enterprise SSO

  #if !os(tvOS) && !os(watchOS)
  /// Authenticates with Enterprise SSO.
  ///
  /// This method prepares the enterprise SSO first factor and initiates the redirect flow.
  /// After the user completes authentication with their identity provider, the callback URL
  /// is handled automatically.
  ///
  /// - Parameters:
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the enterprise SSO flow fails.
  @discardableResult
  @MainActor
  public func authenticateWithEnterpriseSSO(
    prefersEphemeralWebBrowserSession: Bool = false,
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    try await Clerk.shared.auth.authenticateWithEnterpriseSSO(
      for: self,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession,
      transferable: transferable
    )
  }

  /// Authenticates with OAuth using the specified provider.
  ///
  /// This method prepares the OAuth first factor and initiates the redirect flow.
  /// After the user completes authentication with the OAuth provider, the callback URL
  /// is handled automatically.
  ///
  /// - Parameters:
  ///   - provider: The OAuth provider to use (e.g., `.google`, `.github`).
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the OAuth flow fails.
  @discardableResult
  @MainActor
  public func authenticateWithOAuth(
    provider: OAuthProvider,
    prefersEphemeralWebBrowserSession: Bool = false,
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    try await Clerk.shared.auth.authenticateWithOAuth(
      for: self,
      provider: provider,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession,
      transferable: transferable
    )
  }
  #endif

  // MARK: - Passkey

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Authenticates with a passkey.
  ///
  /// This method prepares the passkey first factor, gets the credential from the device,
  /// and completes the authentication flow.
  ///
  /// - Parameters:
  ///   - autofill: Whether to use autofill-assisted flow (default is `false`).
  ///   - preferImmediatelyAvailableCredentials: Whether to prefer immediately available credentials (default is `true`).
  /// - Returns: An updated `SignIn` object reflecting the authentication result.
  /// - Throws: An error if passkey authentication fails.
  @discardableResult
  @MainActor
  public func authenticateWithPasskey(autofill: Bool = false, preferImmediatelyAvailableCredentials: Bool = true) async throws -> SignIn {
    try await Clerk.shared.auth.authenticateWithPasskey(
      for: self,
      autofill: autofill,
      preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
    )
  }
  #endif
}

extension SignIn {
  // MARK: - Internal Helpers

  /// Reloads the current sign-in state from the server.
  ///
  /// - Parameter rotatingTokenNonce: Optional rotating token nonce for reloading.
  /// - Returns: An updated `SignIn` object with the latest state.
  /// - Throws: An error if reloading fails.
  @discardableResult
  @MainActor
  func reload(rotatingTokenNonce: String? = nil) async throws -> SignIn {
    try await Clerk.shared.auth.reload(self, rotatingTokenNonce: rotatingTokenNonce)
  }

  /// Handles the callback url from external authentication. Determines whether to return a sign in or sign up.
  @discardableResult @MainActor
  func handleRedirectCallbackUrl(_ url: URL, transferable: Bool = true) async throws -> TransferFlowResult {
    try await Clerk.shared.auth.handleRedirectCallbackUrl(url, for: self, transferable: transferable)
  }

  /// Determines whether or not to return a sign in or sign up object as part of the transfer flow.
  @MainActor
  func handleTransferFlow(transferable: Bool = true) async throws -> TransferFlowResult {
    try await Clerk.shared.auth.handleTransferFlow(for: self, transferable: transferable)
  }

  /// Helper to determine if the SignIn needs to be transferred to a SignUp
  var needsTransferToSignUp: Bool {
    firstFactorVerification?.status == .transferable || secondFactorVerification?.status == .transferable
  }

  /// The first factor matching the specified strategy string.
  package func identifyingFirstFactor(for strategy: String) -> Factor? {
    supportedFirstFactors?.first(where: { factor in
      factor.strategy.rawValue == strategy && factor.safeIdentifier == identifier
    })
  }

  /// The first factor matching the specified strategy string and identifier.
  package func identifyingFirstFactor(for strategy: String, matching identifier: String) -> Factor? {
    supportedFirstFactors?.first(where: { factor in
      factor.strategy.rawValue == strategy && factor.safeIdentifier == identifier
    })
  }

  /// The second factor matching the specified strategy string.
  func identifyingSecondFactor(for strategy: String) -> Factor? {
    supportedSecondFactors?.first(where: { factor in
      factor.strategy.rawValue == strategy && factor.safeIdentifier == identifier
    })
  }
}
