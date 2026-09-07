import ClerkSnapshots
import Foundation

extension Session {
  /// Marks this session as revoked. If this is the active session, the attempt to revoke it will fail. Users can revoke only their own sessions.
  @discardableResult @MainActor
  public func revoke() async throws -> Session {
    try await Clerk.js(
      .session(id: ClerkJSResourceID(id)),
      SessionWithActivitiesJSCall.revoke,
      as: Session.self
    )
  }

  /**
   Retrieves the user's session token for the given template or the default Clerk token.
   This method uses a cache so a network request will only be made if the token in memory is expired.
   The TTL for the Clerk token is one minute.

   - Returns: The JWT string, or nil if no active session exists.
   */
  @discardableResult @MainActor
  public func getToken(_ options: GetTokenOptions = .init()) async throws -> String? {
    _ = try Clerk.requireStableRuntime()
    return try await Clerk.js(
      .session(id: ClerkJSResourceID(id)),
      SessionJSCall.getToken(
        ClerkSnapshots.GetTokenOptions(expirationBuffer: options.expirationBuffer, skipCache: options.skipCache, template: options.template)
      ),
      as: String?.self
    )
  }

  @MainActor
  func jsStartVerification(level: SessionVerification.Level) async throws -> SessionVerification {
    try await invokeVerification(
      SessionJSCall.startVerification(SessionVerifyCreateParams(level: level.jsLevel))
    )
  }

  @MainActor
  func jsPrepareFirstFactorVerification(
    strategy: FactorStrategy,
    emailAddressId: String?,
    phoneNumberId: String?,
    enterpriseConnectionId: String?,
    redirectUrl: String?
  ) async throws -> SessionVerification {
    try await invokeVerification(
      SessionJSCall.prepareFirstFactorVerification(
        SessionVerifyPrepareFirstFactorParams(
          strategy: strategy.prepareFirstFactorStrategy,
          emailAddressId: emailAddressId,
          phoneNumberId: phoneNumberId,
          enterpriseConnectionId: enterpriseConnectionId,
          redirectUrl: redirectUrl
        )
      )
    )
  }

  @MainActor
  func jsAttemptFirstFactorVerification(
    strategy: FactorStrategy,
    code: String?,
    password: String?,
    publicKeyCredential: String?
  ) async throws -> SessionVerification {
    if let publicKeyCredential {
      return try await invokeVerification(
        JSRawCall(
          "attemptFirstFactorVerification",
          JSONValue(
            encoding: SessionPasskeyAttemptArgs(strategy: strategy.rawValue, publicKeyCredential: publicKeyCredential)
          )
        )
      )
    }
    return try await invokeVerification(
      SessionJSCall.attemptFirstFactorVerification(
        SessionVerifyAttemptFirstFactorParams(
          strategy: strategy.attemptFirstFactorStrategy,
          code: code,
          password: password
        )
      )
    )
  }

  @MainActor
  func jsPrepareSecondFactorVerification(
    strategy: FactorStrategy,
    phoneNumberId: String?
  ) async throws -> SessionVerification {
    try await invokeVerification(
      SessionJSCall.prepareSecondFactorVerification(
        PhoneCodeSecondFactorConfig(strategy: strategy.rawValue, phoneNumberId: phoneNumberId)
      )
    )
  }

  @MainActor
  func jsAttemptSecondFactorVerification(
    strategy: FactorStrategy,
    code: String?,
    publicKeyCredential: String?
  ) async throws -> SessionVerification {
    if let publicKeyCredential {
      return try await invokeVerification(
        JSRawCall(
          "attemptSecondFactorVerification",
          JSONValue(
            encoding: SessionPasskeyAttemptArgs(strategy: strategy.rawValue, publicKeyCredential: publicKeyCredential)
          )
        )
      )
    }
    return try await invokeVerification(
      SessionJSCall.attemptSecondFactorVerification(
        SessionVerifyAttemptSecondFactorParams(
          strategy: strategy.attemptSecondFactorStrategy,
          code: code ?? ""
        )
      )
    )
  }

  @MainActor
  func jsVerifyWithPasskey() async throws -> SessionVerification {
    try await invokeVerification(SessionJSCall.verifyWithPasskey)
  }

  @MainActor
  private func invokeVerification(_ call: some ClerkJSCallable) async throws -> SessionVerification {
    let payload = try await Clerk.requireEngineClient().invoke(
      ClerkJSInvocation(.session(id: ClerkJSResourceID(id)), call)
    )
    var verification = try JSONDecoder.clerkDecoder.decode(SessionVerification.self, from: payload.data())
    if verification.session == nil {
      verification.session = self
    }
    return verification
  }
}

extension SessionVerification.Level {
  fileprivate var jsLevel: SessionVerifyCreateParamsLevel {
    switch self {
    case .firstFactor:
      .firstFactor
    case .secondFactor:
      .secondFactor
    case .multiFactor:
      .multiFactor
    case .unknown(let value):
      .unknown(value)
    }
  }
}

extension FactorStrategy {
  fileprivate var prepareFirstFactorStrategy: SessionVerifyPrepareFirstFactorParamsStrategy {
    switch self {
    case .passkey:
      .passkey
    case .emailCode:
      .emailCode
    case .phoneCode:
      .phoneCode
    case .enterpriseSSO:
      .enterpriseSso
    default:
      .unknown(rawValue)
    }
  }

  fileprivate var attemptFirstFactorStrategy: SessionVerifyAttemptFirstFactorParamsStrategy {
    switch self {
    case .passkey:
      .passkey
    case .emailCode:
      .emailCode
    case .phoneCode:
      .phoneCode
    case .password:
      .password
    default:
      .unknown(rawValue)
    }
  }

  fileprivate var attemptSecondFactorStrategy: SessionVerifyAttemptSecondFactorParamsStrategy {
    switch self {
    case .phoneCode:
      .phoneCode
    case .totp:
      .totp
    case .backupCode:
      .backupCode
    default:
      .unknown(rawValue)
    }
  }
}

private struct SessionPasskeyAttemptArgs: Encodable {
  var strategy: String
  var publicKeyCredential: String
}
