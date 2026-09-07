#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
@testable import ClerkKit
import ClerkSnapshots
import Testing

@MainActor
@Suite(.serialized)
struct AuthAppleTests {
  @Test
  func appleCredentialOptionsAndResultCrossTheEngineBoundary() async throws {
    configureClerkForTesting()
    let engine = RecordingEngineClient()
    engine.nativeCompletionResult = .signUp(SignUp.mock)
    Clerk.engineClient = engine
    let result = try await Clerk.shared.auth.completeAppleSignIn(
      idToken: "apple_token", firstName: "Jane", lastName: "Doe", transferable: false, unsafeMetadata: ["plan": "pro"]
    )
    #expect(engine.nativeAppleArguments == .object([
      "idToken": .string("apple_token"), "firstName": .string("Jane"), "lastName": .string("Doe"),
      "transferable": .bool(false), "unsafeMetadata": .object(["plan": .string("pro")]),
    ]))
    guard case .signUp(let signUp) = result else { Issue.record("Expected the engine's sign-up result"); return }
    #expect(signUp.id == SignUp.mock.id)
  }
}
#endif
