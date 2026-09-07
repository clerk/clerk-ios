import ClerkSnapshots
import Foundation

extension Clerk {
  @MainActor
  package static func js(_ receiver: ClerkJSReceiver, _ call: some ClerkJSCallable) async throws {
    _ = try await requireEngineClient().invoke(ClerkJSInvocation(receiver, call))
  }

  @MainActor
  package static func js<R: Decodable>(
    _ receiver: ClerkJSReceiver,
    _ call: some ClerkJSCallable,
    as _: R.Type
  ) async throws -> R {
    let payload = try await requireEngineClient().invoke(ClerkJSInvocation(receiver, call))
    return try JSONDecoder.clerkDecoder.decode(R.self, from: payload.data())
  }

  @MainActor
  package static func requireUser() throws -> User {
    guard let user = shared.user else {
      throw ClerkClientError(message: "The JS call did not produce a user.")
    }
    return user
  }

  @MainActor
  package static func requireSession() throws -> Session {
    guard let session = shared.session else {
      throw ClerkClientError(message: "The JS call did not produce a session.")
    }
    return session
  }

  @MainActor
  static func finishedSignIn() async throws -> SignIn {
    try await js(.clerk, JSRawCall("finishNativeSignIn"))
    return try requireEngineSignIn()
  }

  @MainActor
  static func finishedSignUp() async throws -> SignUp {
    try await js(.clerk, JSRawCall("finishNativeSignUp"))
    return try requireEngineSignUp()
  }

  @MainActor
  static func completeNativeAuth(
    flow: String,
    expectedId: String? = nil,
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil
  ) async throws -> TransferFlowResult {
    let result = try await js(
      .clerk,
      JSRawCall("completeNativeAuth", JSONValue(encoding: NativeAuthCompletionArgs(
        flow: flow, expectedId: expectedId, transferable: transferable, unsafeMetadata: unsafeMetadata?.jsonValue
      ))),
      as: NativeAuthResult.self
    )
    return try result.transferResult()
  }

  @MainActor
  static var oauthRedirectURL: String {
    let configured = shared.options.redirectConfig.redirectUrl
    if !configured.isEmpty {
      return configured
    }
    let scheme = Bundle.main.bundleIdentifier ?? "clerk"
    return "\(scheme)://sso-callback"
  }

  @MainActor
  static func authenticateWithRedirect(
    strategy: String,
    identifier: String? = nil,
    prefersEphemeralWebBrowserSession: Bool = false,
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil
  ) async throws -> TransferFlowResult {
    let result = try await js(
      .clerk,
      JSRawCall(
        "authenticateNativeWithRedirect",
        JSONValue(
          encoding: NativeRedirectArgs(flow: "signIn", params: SignInRedirectArgs(
            strategy: strategy,
            redirectUrl: oauthRedirectURL,
            identifier: identifier,
            __internal_callbackParams: .init(transferable: transferable, unsafeMetadata: unsafeMetadata?.jsonValue),
            __internal_oauthOptions: .init(prefersEphemeralSession: prefersEphemeralWebBrowserSession)
          ))
        )
      ), as: NativeAuthResult.self
    )
    return try result.transferResult()
  }

  @MainActor
  static func authenticateSignUpWithRedirect(
    strategy: String,
    emailAddress: String? = nil,
    prefersEphemeralWebBrowserSession: Bool = false,
    unsafeMetadata: JSON? = nil
  ) async throws -> TransferFlowResult {
    let result = try await js(
      .clerk,
      JSRawCall(
        "authenticateNativeWithRedirect",
        JSONValue(
          encoding: NativeRedirectArgs(flow: "signUp", params: SignUpRedirectArgs(
            strategy: strategy,
            redirectUrl: oauthRedirectURL,
            emailAddress: emailAddress,
            unsafeMetadata: unsafeMetadata?.jsonValue,
            __internal_callbackParams: .init(transferable: true, unsafeMetadata: unsafeMetadata?.jsonValue),
            __internal_oauthOptions: .init(prefersEphemeralSession: prefersEphemeralWebBrowserSession)
          ))
        )
      ), as: NativeAuthResult.self
    )
    return try result.transferResult()
  }
}

private struct SignInRedirectArgs: Encodable {
  var strategy: String
  var redirectUrl: String
  var identifier: String?
  var __internal_callbackParams: RedirectCallbackArgs
  var __internal_oauthOptions: OAuthBrowserOptions
}

private struct SignUpRedirectArgs: Encodable {
  var strategy: String
  var redirectUrl: String
  var emailAddress: String?
  var unsafeMetadata: JSONValue?
  var __internal_callbackParams: RedirectCallbackArgs
  var __internal_oauthOptions: OAuthBrowserOptions
}

private struct RedirectCallbackArgs: Encodable {
  var transferable: Bool
  var unsafeMetadata: JSONValue?
}

private struct OAuthBrowserOptions: Encodable {
  var prefersEphemeralSession: Bool
}

extension JSON {
  var jsonValue: JSONValue {
    (try? JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(self))) ?? .null
  }
}

private struct NativeAuthCompletionArgs: Encodable {
  var flow: String
  var expectedId: String?
  var transferable: Bool
  var unsafeMetadata: JSONValue?
}

struct NativeAuthResult: Decodable {
  var kind: String
  var resource: JSONValue

  func transferResult() throws -> TransferFlowResult {
    switch kind {
    case "signIn":
      return try .signIn(JSONDecoder.clerkDecoder.decode(SignIn.self, from: resource.data()))
    case "signUp":
      return try .signUp(JSONDecoder.clerkDecoder.decode(SignUp.self, from: resource.data()))
    default:
      throw ClerkClientError(message: "Unknown authentication result from the shared runtime.")
    }
  }
}

private struct NativeRedirectArgs<Params: Encodable>: Encodable {
  var flow: String
  var params: Params
}
