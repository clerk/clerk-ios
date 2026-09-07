import ClerkSnapshots
import Foundation

extension SignUp {
  @discardableResult
  @MainActor
  func reload(rotatingTokenNonce: String? = nil) async throws -> SignUp {
    try await Clerk.js(
      .signUp,
      SignUpJSCall.reload(
        rotatingTokenNonce.map { ClerkResourceReloadParams(rotatingTokenNonce: $0) }
      )
    )
    return try Clerk.requireEngineSignUp()
  }

  /// This method is used to update the current sign-up.
  ///
  /// This method is used to modify the details of an ongoing sign-up process.
  /// It allows you to update any fields previously specified during the sign-up flow,
  /// such as personal information, email, phone number, or other attributes.
  ///
  /// - Parameters:
  ///   - emailAddress: The user's email address (optional).
  ///   - password: The user's password (optional).
  ///   - firstName: The user's first name (optional).
  ///   - lastName: The user's last name (optional).
  ///   - username: The user's username (optional).
  ///   - phoneNumber: The user's phone number in E.164 format (optional).
  ///   - unsafeMetadata: Custom metadata to attach to the user (optional).
  ///   - legalAccepted: Whether the user has accepted legal terms (optional).
  /// - Returns: The updated `SignUp` object reflecting the changes.
  /// - Throws: An error if the update operation fails, such as due to invalid parameters or network issues.
  @discardableResult
  @MainActor
  public func update(
    emailAddress: String? = nil,
    password: String? = nil,
    firstName: String? = nil,
    lastName: String? = nil,
    username: String? = nil,
    phoneNumber: String? = nil,
    unsafeMetadata _: JSON? = nil,
    legalAccepted: Bool? = nil
  ) async throws -> SignUp {
    try await Clerk.js(
      .signUp,
      SignUpJSCall.update(
        SignUpCreateParams(
          legalAccepted: legalAccepted,
          username: username,
          password: password,
          firstName: firstName,
          lastName: lastName,
          emailAddress: emailAddress,
          phoneNumber: phoneNumber
        )
      )
    )
    return try await Clerk.finishedSignUp()
  }

  /// Sends a native magic link to the email address for verification.
  ///
  /// This prepares the `email_link` verification using PKCE and stores the verifier locally
  /// so the callback can be completed inside the app.
  ///
  /// - Parameter redirectUri: Optional redirect URI override. Defaults to the Clerk redirect configuration.
  /// - Returns: An updated `SignUp` object with the email-link verification started.
  /// - Throws: An error if the redirect URI is missing or preparation fails.
  @discardableResult
  @MainActor
  public func sendEmailLink(redirectUri: String? = nil) async throws -> SignUp {
    let resolvedRedirectUri = redirectUri ?? Clerk.shared.options.redirectConfig.redirectUrl
    guard !resolvedRedirectUri.isEmpty else {
      throw ClerkClientError(message: "Redirect URI is missing. Unable to start email link sign-up verification.", localizationBundle: .module)
    }

    let pkcePair = try PKCE.generatePair()
    try Clerk.shared.dependencies.magicLinkStore.save(
      kind: .signUp,
      flowId: id,
      codeVerifier: pkcePair.verifier,
      authFlowOwnerId: AuthFlowRequestScope.ownerId
    )

    try await Clerk.js(
      .signUp,
      JSRawCall(
        "prepareVerification",
        JSONValue(
          encoding: SignUpEmailLinkArgs(
            redirectUrl: resolvedRedirectUri,
            codeChallenge: pkcePair.challenge,
            codeChallengeMethod: PKCE.codeChallengeMethod
          )
        )
      )
    )
    return try Clerk.requireEngineSignUp()
  }

  /// Sends a verification code to the email address.
  ///
  /// - Returns: An updated `SignUp` object with the verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendEmailCode() async throws -> SignUp {
    try await Clerk.js(
      .signUp,
      SignUpJSCall.prepareVerification(ClerkSnapshots.PrepareVerificationParams(strategy: "email_code"))
    )
    return try Clerk.requireEngineSignUp()
  }

  /// Sends a verification code to the phone number.
  ///
  /// - Returns: An updated `SignUp` object with the verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendPhoneCode() async throws -> SignUp {
    try await Clerk.js(
      .signUp,
      SignUpJSCall.prepareVerification(ClerkSnapshots.PrepareVerificationParams(strategy: "phone_code"))
    )
    return try Clerk.requireEngineSignUp()
  }

  /// Verifies the email code entered by the user.
  ///
  /// - Parameter code: The verification code entered by the user.
  /// - Returns: The updated `SignUp` object reflecting the verification result.
  /// - Throws: An error if verification fails.
  @discardableResult
  @MainActor
  public func verifyEmailCode(_ code: String) async throws -> SignUp {
    try await Clerk.js(
      .signUp,
      SignUpJSCall.attemptVerification(
        ClerkSnapshots.AttemptVerificationParams(strategy: .emailCode, code: code)
      )
    )
    return try await Clerk.finishedSignUp()
  }

  /// Verifies the phone code entered by the user.
  ///
  /// - Parameter code: The verification code entered by the user.
  /// - Returns: The updated `SignUp` object reflecting the verification result.
  /// - Throws: An error if verification fails.
  @discardableResult
  @MainActor
  public func verifyPhoneCode(_ code: String) async throws -> SignUp {
    try await Clerk.js(
      .signUp,
      SignUpJSCall.attemptVerification(
        ClerkSnapshots.AttemptVerificationParams(strategy: .phoneCode, code: code)
      )
    )
    return try await Clerk.finishedSignUp()
  }

  @MainActor
  func handleTransferFlow() async throws -> TransferFlowResult {
    if needsTransferToSignIn == true {
      try await Clerk.js(.signIn, SignInJSCall.create(SignInCreateParams(transfer: true)))
      return try await .signIn(Clerk.finishedSignIn())
    } else {
      return .signUp(self)
    }
  }
}

private struct SignUpEmailLinkArgs: Encodable {
  var strategy = "email_link"
  var redirectUrl: String
  var codeChallenge: String
  var codeChallengeMethod: String
}
