import ClerkKit
import Foundation
import Testing

/// Runs the generated future-style API against the configured development
/// instance. The instance must support password sign-up and email test codes.
@MainActor
@Suite(.serialized, .enabled(if: integrationTestsEnabled(keyName: "with-email-codes"), "Requires with-email-codes in .keys.json"))
struct AuthAndClientIntegrationTests {
  private static let testPassword = "Clerk_iOS_Test_2025_XyZ9#mK2$pL7"
  private static let testVerificationCode = "424242"

  @Test
  func signUpAndSignIn() async throws {
    let clerk = try await connectClerkForIntegrationTesting(keyName: "with-email-codes")
    defer { clerk.close() }
    let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    let email = "test+clerk_test_\(suffix)@example.com"
    var didCreateSignUp = false

    do {
      try await clerk.signUp.create(.init(emailAddress: email, password: Self.testPassword))
      didCreateSignUp = true
      #expect(clerk.signUp.emailAddress == email)
      try await clerk.signUp.verifications.sendEmailCode()
      try await clerk.signUp.verifications.verifyEmailCode(.init(code: Self.testVerificationCode))
      try #require(clerk.signUp.status == .complete)
      let createdUserId = try #require(clerk.signUp.createdUserId)
      let createdSessionId = try #require(clerk.signUp.createdSessionId)
      #expect(clerk.session == nil)
      #expect(clerk.user == nil)
      try await clerk.signUp.finalize()
      #expect(clerk.session?.id == createdSessionId)
      #expect(clerk.user?.id == createdUserId)

      try await clerk.signOut()
      #expect(clerk.session == nil)
      #expect(clerk.user == nil)

      try await clerk.signIn.emailCode.sendCode(.case1(.init(emailAddress: email)))
      try await clerk.signIn.emailCode.verifyCode(.init(code: Self.testVerificationCode))
      try #require(clerk.signIn.status == .complete)
      let signInSessionId = try #require(clerk.signIn.createdSessionId)
      #expect(clerk.session == nil)
      #expect(clerk.user == nil)
      try await clerk.signIn.finalize()
      #expect(clerk.session?.id == signInSessionId)
      let user = try #require(clerk.user)
      #expect(user.id == createdUserId)
      // Cleanup is required on the successful path, rather than silently ignored.
      _ = try await user.delete()
    } catch {
      await deleteTestAccountIfExists(clerk: clerk, email: email, allowPasswordCleanup: didCreateSignUp)
      throw error
    }
  }

  private func deleteTestAccountIfExists(clerk: Clerk, email: String, allowPasswordCleanup: Bool) async {
    do {
      if let user = clerk.user {
        _ = try await user.delete()
        return
      }
      guard allowPasswordCleanup else { return }
      try await clerk.signIn.password(.case1(.init(password: Self.testPassword, identifier: email)))
      guard clerk.signIn.status == .complete else { return }
      try await clerk.signIn.finalize()
      _ = try await clerk.user?.delete()
    } catch {
      // Preserve the original failure. An incomplete sign-up may have no account
      // to delete; a completed account may require instance-side cleanup.
    }
  }
}
