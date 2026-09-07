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
}
