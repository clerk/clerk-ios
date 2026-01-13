import ConcurrencyExtras
import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct SignInTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  private func configureService(_ service: MockSignInService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      signInService: service
    )
  }

  @Test
  func sendEmailCodeUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.PrepareFirstFactorParams)?>(nil)
    let service = MockSignInService(prepareFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.sendEmailCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .emailCode)
  }

  @Test
  func sendPhoneCodeUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.PrepareFirstFactorParams)?>(nil)
    let service = MockSignInService(prepareFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.sendPhoneCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .phoneCode)
  }

  @Test
  func verifyCodeUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.AttemptFirstFactorParams)?>(nil)
    let service = MockSignInService(attemptFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.verifyCode("123456")

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .emailCode)
    #expect(params.1.code == "123456")
  }

  @Test
  func authenticateWithPasswordUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.AttemptFirstFactorParams)?>(nil)
    let service = MockSignInService(attemptFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.authenticateWithPassword("password123")

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .password)
    #expect(params.1.password == "password123")
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @Test
  func authenticateWithIdTokenUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.AttemptFirstFactorParams)?>(nil)
    let service = MockSignInService(attemptFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.authenticateWithIdToken("mock_id_token", provider: .apple)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .idToken(.apple))
    #expect(params.1.token == "mock_id_token")
  }
  #endif

  @Test
  func sendMfaPhoneCodeUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.PrepareSecondFactorParams)?>(nil)
    let service = MockSignInService(prepareSecondFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.sendMfaPhoneCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .phoneCode)
  }

  @Test
  func sendMfaEmailCodeUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.PrepareSecondFactorParams)?>(nil)
    let service = MockSignInService(prepareSecondFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.sendMfaEmailCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .emailCode)
  }

  @Test
  func verifyMfaPhoneCodeUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.AttemptSecondFactorParams)?>(nil)
    let service = MockSignInService(attemptSecondFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.verifyMfaCode("123456", type: .phoneCode)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .phoneCode)
    #expect(params.1.code == "123456")
  }

  @Test
  func verifyMfaTotpUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.AttemptSecondFactorParams)?>(nil)
    let service = MockSignInService(attemptSecondFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.verifyMfaCode("654321", type: .totp)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .totp)
    #expect(params.1.code == "654321")
  }

  @Test
  func verifyMfaBackupCodeUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.AttemptSecondFactorParams)?>(nil)
    let service = MockSignInService(attemptSecondFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.verifyMfaCode("backup123", type: .backupCode)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .backupCode)
    #expect(params.1.code == "backup123")
  }

  @Test
  func sendResetPasswordEmailCodeUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.PrepareFirstFactorParams)?>(nil)
    let service = MockSignInService(prepareFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.sendResetPasswordEmailCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .resetPasswordEmailCode)
  }

  @Test
  func sendResetPasswordPhoneCodeUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.PrepareFirstFactorParams)?>(nil)
    let service = MockSignInService(prepareFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.sendResetPasswordPhoneCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .resetPasswordPhoneCode)
  }

  @Test
  func resetPasswordUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.ResetPasswordParams)?>(nil)
    let service = MockSignInService(resetPassword: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.resetPassword(newPassword: "newPassword123", signOutOfOtherSessions: true)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.password == "newPassword123")
    #expect(params.1.signOutOfOtherSessions == true)
  }

  @Test
  func reloadUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.GetParams)?>(nil)
    let service = MockSignInService(get: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.reload()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.rotatingTokenNonce == nil)
  }

  @Test
  func reloadWithRotatingTokenNonceUsesService() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.GetParams)?>(nil)
    let service = MockSignInService(get: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.reload(rotatingTokenNonce: "test_nonce")

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.rotatingTokenNonce == "test_nonce")
  }
}
