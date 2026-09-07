import ClerkSnapshots
import Foundation

extension SignIn {
  @discardableResult
  @MainActor
  func reload(rotatingTokenNonce: String? = nil) async throws -> SignIn {
    try await Clerk.js(
      .signIn,
      SignInJSCall.reload(
        rotatingTokenNonce.map { ClerkResourceReloadParams(rotatingTokenNonce: $0) }
      )
    )
    return try Clerk.requireEngineSignIn()
  }

  @MainActor
  static func preparePasskeyFirstFactor() async throws {
    try await Clerk.js(
      .signIn,
      SignInJSCall.prepareFirstFactor(
        ClerkSnapshots.PrepareFirstFactorParams(
          strategy: "passkey",
          redirectUrl: Clerk.shared.options.redirectConfig.redirectUrl
        )
      )
    )
  }

  @MainActor
  static func preparePasskeySecondFactor() async throws {
    try await Clerk.js(
      .signIn,
      SignInJSCall.prepareSecondFactor(
        ClerkSnapshots.PrepareSecondFactorParams(strategy: .unknown("passkey"))
      )
    )
  }

  @MainActor
  static func attemptPasskeyFirstFactor(credential: String) async throws {
    try await Clerk.js(
      .signIn,
      JSRawCall("attemptFirstFactor", JSONValue(encoding: PasskeyAttemptArgs(publicKeyCredential: credential)))
    )
  }

  @MainActor
  static func attemptPasskeySecondFactor(credential: String) async throws {
    try await Clerk.js(
      .signIn,
      JSRawCall("attemptSecondFactor", JSONValue(encoding: PasskeyAttemptArgs(publicKeyCredential: credential)))
    )
  }
}

private struct PasskeyAttemptArgs: Encodable {
  var strategy = "passkey"
  var publicKeyCredential: String
}
