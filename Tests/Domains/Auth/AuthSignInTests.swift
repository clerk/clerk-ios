@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct AuthSignInTests {
  private let support = AuthTestSupport()

  @Test
  func signInWithIdentifierUsesSignInServiceCreate() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    let clerk = try support.makeClerk(signInService: signInService)

    _ = try await clerk.auth.signIn("test@example.com")

    let params = try #require(signInParams.value)
    #expect(params.identifier == "test@example.com")
  }

  @Test
  func sendEmailCodeForExistingSignInUsesSignInServicePrepareFirstFactor() async throws {
    let captured = LockIsolated<(String, SignIn.PrepareFirstFactorParams)?>(nil)
    let signInService = MockSignInService(prepareFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    let clerk = try support.makeClerk(signInService: signInService)

    _ = try await clerk.auth.sendEmailCode(for: SignIn.mock)

    let params = try #require(captured.value)
    #expect(params.0 == SignIn.mock.id)
    #expect(params.1.strategy == .emailCode)
  }

  @Test
  func signInWithPasswordUsesSignInServiceCreate() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    let clerk = try support.makeClerk(signInService: signInService)

    _ = try await clerk.auth.signInWithPassword(identifier: "test@example.com", password: "password123")

    let params = try #require(signInParams.value)
    #expect(params.identifier == "test@example.com")
    #expect(params.password == "password123")
  }

  @Test
  func signInWithOAuthUsesSignInServiceCreate() async throws {
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

    let clerk = try support.makeClerk(signInService: signInService, signUpService: signUpService)

    do {
      _ = try await clerk.auth.signInWithOAuth(provider: .google)
    } catch {}

    #expect(signUpCalled.value == false)
    let params = try #require(signInParams.value)
    #expect(params.strategy?.rawValue == OAuthProvider.google.strategy)
  }

  @Test
  func signInWithEnterpriseSSOUsesSignInServiceCreate() async throws {
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

    let clerk = try support.makeClerk(signInService: signInService, signUpService: signUpService)

    do {
      _ = try await clerk.auth.signInWithEnterpriseSSO(emailAddress: "user@enterprise.com")
    } catch {}

    #expect(signUpCalled.value == false)
    let params = try #require(signInParams.value)
    #expect(params.identifier == "user@enterprise.com")
  }

  @Test
  func startEnterpriseSSOUsesSignInServiceCreateAndPrepareFirstFactor() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let prepareParams = LockIsolated<(String, SignIn.PrepareFirstFactorParams)?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    }, prepareFirstFactor: { id, params in
      prepareParams.setValue((id, params))
      return .mock
    })

    let clerk = try support.makeClerk(signInService: signInService)

    _ = try await clerk.auth.startEnterpriseSSO(
      emailAddress: "user@enterprise.com",
      redirectUrl: "myapp://callback"
    )

    let params = try #require(signInParams.value)
    #expect(params.identifier == "user@enterprise.com")
    #expect(params.strategy == .enterpriseSSO)
    #expect(params.redirectUrl == "myapp://callback")

    let prepared = try #require(prepareParams.value)
    #expect(prepared.0 == SignIn.mock.id)
    #expect(prepared.1.strategy == .enterpriseSSO)
    #expect(prepared.1.redirectUrl == "myapp://callback")
  }

  @Test
  func signInWithIdTokenUsesSignInServiceCreate() async throws {
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

    let clerk = try support.makeClerk(signInService: signInService, signUpService: signUpService)

    _ = try await clerk.auth.signInWithIdToken("mock_id_token", provider: .apple)

    #expect(signUpCalled.value == false)
    let params = try #require(signInParams.value)
    #expect(params.strategy?.rawValue == IDTokenProvider.apple.strategy)
    #expect(params.token == "mock_id_token")
  }

  @Test
  func signInWithIdTokenThrowsWhenTransferableButDisallowed() async throws {
    let signUpCalled = LockIsolated(false)
    let didThrow = LockIsolated(false)
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(
      status: .transferable,
      strategy: .idToken(.apple),
      error: .mock
    )

    let signInService = MockSignInService(create: { _ in signIn })
    let signUpService = MockSignUpService(create: { _ in
      signUpCalled.setValue(true)
      return .mock
    })

    let clerk = try support.makeClerk(signInService: signInService, signUpService: signUpService)

    do {
      _ = try await clerk.auth.signInWithIdToken(
        "mock_id_token",
        provider: .apple,
        transferable: false
      )
      #expect(Bool(false))
    } catch {
      didThrow.setValue(true)
    }

    #expect(signUpCalled.value == false)
    #expect(didThrow.value == true)
  }

  @Test
  func signInWithPasskeyUsesOneShotPasskeySignIn() async throws {
    var preparedSignIn = SignIn.mock
    preparedSignIn.firstFactorVerification = nil

    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let preparedSignInId = LockIsolated<String?>(nil)
    let preparedParams = LockIsolated<SignIn.PrepareFirstFactorParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    }, prepareFirstFactor: { signInId, params in
      preparedSignInId.setValue(signInId)
      preparedParams.setValue(params)
      return preparedSignIn
    })

    let clerk = try support.makeClerk(signInService: signInService)

    do {
      _ = try await clerk.auth.signInWithPasskey()
    } catch {}

    let createParams = try #require(signInParams.value)
    #expect(createParams.strategy == .passkey)
    #expect(preparedSignInId.value == SignIn.mock.id)

    let prepareParams = try #require(preparedParams.value)
    #expect(prepareParams.strategy == .passkey)
  }

  @Test
  func signInWithTicketUsesSignInServiceCreate() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    let clerk = try support.makeClerk(signInService: signInService)

    _ = try await clerk.auth.signInWithTicket("mock_ticket_value")

    let params = try #require(signInParams.value)
    #expect(params.ticket == "mock_ticket_value")
  }
}
