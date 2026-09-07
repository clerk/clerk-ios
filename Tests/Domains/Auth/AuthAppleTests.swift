#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)

import AuthenticationServices
@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct AuthAppleTests {
  init() {
    configureClerkForTesting()
  }

  private func installEngine(_ engine: RecordingEngineClient = RecordingEngineClient()) -> RecordingEngineClient {
    configureClerkForTesting()
    Clerk.engineClient = engine
    Clerk.shared.environment = .mock
    Clerk.shared.setCallbackContinuation(nil)
    return engine
  }

  private func restrictionError(_ code: String) -> ClerkAPIError {
    ClerkAPIError(
      code: code,
      message: "Sign-up is restricted",
      longMessage: nil,
      meta: nil,
      clerkTraceId: nil
    )
  }

  @Test
  func appleSignInSkipsSignUpWhenTransferIsDisabled() async throws {
    let engine = installEngine()

    let result = try await Clerk.shared.auth.completeAppleSignIn(
      idToken: "apple_token",
      firstName: "Jane",
      lastName: "Doe",
      transferable: false,
      unsafeMetadata: ["plan": "pro"]
    )

    guard case .signIn = result else {
      Issue.record("Expected a sign-in result")
      return
    }
    #expect(engine.signedUpIdToken == nil)
    #expect(engine.signedInIdToken == "apple_token")
    #expect(engine.signedInIdTokenStrategy == "oauth_token_apple")
  }

  @Test
  func appleSignInStartsWithSignUpAndPreservesAppleProfile() async throws {
    let engine = installEngine()

    let result = try await Clerk.shared.auth.completeAppleSignIn(
      idToken: "apple_token",
      firstName: "Jane",
      lastName: "Doe",
      transferable: true,
      unsafeMetadata: ["plan": "pro"]
    )

    guard case .signUp = result else {
      Issue.record("Expected a sign-up result")
      return
    }
    #expect(engine.signedInIdToken == nil)
    #expect(engine.signedUpIdToken == "apple_token")
    #expect(engine.signedUpIdTokenStrategy == "oauth_token_apple")
    #expect(engine.signedUpFirstName == "Jane")
    #expect(engine.signedUpLastName == "Doe")
  }

  @Test
  func appleSignInTransfersSuccessfulSignUpToExistingUser() async throws {
    let engine = installEngine()
    engine.signInPublishedBySignUpIdToken = SignIn(
      id: "sia_engine",
      status: .complete,
      createdSessionId: "sess_engine"
    )

    let result = try await Clerk.shared.auth.completeAppleSignIn(
      idToken: "apple_token",
      firstName: "Jane",
      lastName: "Doe",
      transferable: true,
      unsafeMetadata: nil
    )

    guard case .signIn = result else {
      Issue.record("Expected a sign-in result")
      return
    }
    #expect(engine.signedUpIdToken == "apple_token")
    #expect(engine.signedInIdToken == nil)
  }

  @Test
  func appleSignInThrowsVerificationErrorAfterSignUpTransfersToSignIn() async throws {
    let verificationError = ClerkAPIError(
      code: "account_locked",
      message: "Account is locked",
      longMessage: nil,
      meta: nil,
      clerkTraceId: nil
    )
    var failedSignIn = SignIn.mock
    failedSignIn.firstFactorVerification = Verification(
      status: .failed,
      strategy: .idToken(.apple),
      error: verificationError
    )

    let engine = installEngine()
    engine.signInPublishedBySignUpIdToken = failedSignIn

    do {
      _ = try await Clerk.shared.auth.completeAppleSignIn(
        idToken: "apple_token",
        firstName: "Jane",
        lastName: "Doe",
        transferable: true,
        unsafeMetadata: nil
      )
      Issue.record("Expected the transferred sign-in verification error")
    } catch let error as ClerkAPIError {
      #expect(error == verificationError)
    }
  }

  @Test(arguments: [
    "sign_up_mode_restricted",
    "sign_up_restricted_waitlist",
  ])
  func appleSignInFallsBackForRestrictedSignUp(errorCode: String) async throws {
    let engine = installEngine()
    engine.signUpWithIdTokenError = restrictionError(errorCode)

    let result = try await Clerk.shared.auth.completeAppleSignIn(
      idToken: "apple_token",
      firstName: "Jane",
      lastName: "Doe",
      transferable: true,
      unsafeMetadata: nil
    )

    guard case .signIn = result else {
      Issue.record("Expected a sign-in result")
      return
    }
    #expect(engine.signedUpIdToken == nil)
    #expect(engine.signedInIdToken == "apple_token")
    #expect(engine.signedInIdTokenStrategy == "oauth_token_apple")
  }

  @Test(arguments: [
    "sign_up_mode_restricted",
    "sign_up_restricted_waitlist",
  ])
  func appleSignInKeepsNewUsersBlocked(errorCode: String) async throws {
    let restrictionError = restrictionError(errorCode)
    var transferableSignIn = SignIn.mock
    transferableSignIn.firstFactorVerification = Verification(
      status: .transferable,
      strategy: .idToken(.apple),
      error: .mock
    )

    let engine = installEngine()
    engine.signUpWithIdTokenError = restrictionError
    engine.signInPublishedByIdToken = transferableSignIn

    do {
      _ = try await Clerk.shared.auth.completeAppleSignIn(
        idToken: "apple_token",
        firstName: "Jane",
        lastName: "Doe",
        transferable: true,
        unsafeMetadata: nil
      )
      Issue.record("Expected the original sign-up restriction error")
    } catch let error as ClerkAPIError {
      #expect(error == restrictionError)
    }
  }

  @Test
  func appleSignInDoesNotFallbackForUnrelatedSignUpError() async throws {
    let unrelatedError = ClerkAPIError(
      code: "form_param_invalid",
      message: "Invalid parameter",
      longMessage: nil,
      meta: nil,
      clerkTraceId: nil
    )
    let engine = installEngine()
    engine.signUpWithIdTokenError = unrelatedError

    do {
      _ = try await Clerk.shared.auth.completeAppleSignIn(
        idToken: "apple_token",
        firstName: "Jane",
        lastName: "Doe",
        transferable: true,
        unsafeMetadata: nil
      )
      Issue.record("Expected the unrelated sign-up error")
    } catch let error as ClerkAPIError {
      #expect(error == unrelatedError)
    }
    #expect(engine.signedInIdToken == nil)
  }
}

#endif
