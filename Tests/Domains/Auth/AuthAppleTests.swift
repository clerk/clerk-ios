#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)

import AuthenticationServices
@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct AuthAppleTests {
  init() {
    configureClerkForTesting()
  }

  private func configureDependencies(
    signInService: MockSignInService = .init(),
    signUpService: MockSignUpService = .init()
  ) {
    configureClerkForTesting()
    let apiClient = createMockAPIClient(baseURL: mockBaseUrl)
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: apiClient,
      signInService: signInService,
      signUpService: signUpService
    )
    try! (Clerk.shared.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: .init())
    Clerk.shared.environment = .mock
    Clerk.shared.setCallbackContinuation(nil)
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
    let signUpCalled = LockIsolated(false)
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })
    let signUpService = MockSignUpService(create: { _ in
      signUpCalled.setValue(true)
      return .mock
    })
    configureDependencies(signInService: signInService, signUpService: signUpService)

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
    #expect(signUpCalled.value == false)
    let params = try #require(signInParams.value)
    #expect(params.strategy == .idToken(.apple))
    #expect(params.token == "apple_token")
  }

  @Test
  func appleSignInStartsWithSignUpAndPreservesAppleProfile() async throws {
    let metadata: JSON = ["plan": "pro"]
    let signInCalled = LockIsolated(false)
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
    let signInService = MockSignInService(create: { _ in
      signInCalled.setValue(true)
      return .mock
    })
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return .mock
    })
    configureDependencies(signInService: signInService, signUpService: signUpService)

    let result = try await Clerk.shared.auth.completeAppleSignIn(
      idToken: "apple_token",
      firstName: "Jane",
      lastName: "Doe",
      transferable: true,
      unsafeMetadata: metadata
    )

    guard case .signUp = result else {
      Issue.record("Expected a sign-up result")
      return
    }
    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params.strategy == .idToken(.apple))
    #expect(params.token == "apple_token")
    #expect(params.firstName == "Jane")
    #expect(params.lastName == "Doe")
    #expect(params.unsafeMetadata == metadata)
  }

  @Test
  func appleSignInTransfersSuccessfulSignUpToExistingUser() async throws {
    var transferableSignUp = SignUp.mock
    transferableSignUp.verifications["external_account"] = Verification(status: .transferable)

    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })
    let signUpService = MockSignUpService(create: { _ in
      transferableSignUp
    })
    configureDependencies(signInService: signInService, signUpService: signUpService)

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
    let params = try #require(signInParams.value)
    #expect(params.transfer == true)
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
    var transferableSignUp = SignUp.mock
    transferableSignUp.verifications["external_account"] = Verification(status: .transferable)
    var failedSignIn = SignIn.mock
    failedSignIn.firstFactorVerification = Verification(
      status: .failed,
      strategy: .idToken(.apple),
      error: verificationError
    )

    let signInService = MockSignInService(create: { _ in
      failedSignIn
    })
    let signUpService = MockSignUpService(create: { _ in
      transferableSignUp
    })
    configureDependencies(signInService: signInService, signUpService: signUpService)

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
    let error = restrictionError(errorCode)
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })
    let signUpService = MockSignUpService(create: { _ in
      throw error
    })
    configureDependencies(signInService: signInService, signUpService: signUpService)

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
    let params = try #require(signInParams.value)
    #expect(params.strategy == .idToken(.apple))
    #expect(params.token == "apple_token")
    #expect(params.transfer == nil)
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

    let signInService = MockSignInService(create: { _ in
      transferableSignIn
    })
    let signUpService = MockSignUpService(create: { _ in
      throw restrictionError
    })
    configureDependencies(signInService: signInService, signUpService: signUpService)

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
    let signInCalled = LockIsolated(false)
    let signInService = MockSignInService(create: { _ in
      signInCalled.setValue(true)
      return .mock
    })
    let signUpService = MockSignUpService(create: { _ in
      throw unrelatedError
    })
    configureDependencies(signInService: signInService, signUpService: signUpService)

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
    #expect(signInCalled.value == false)
  }
}

#endif
