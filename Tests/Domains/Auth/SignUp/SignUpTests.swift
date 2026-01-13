import ConcurrencyExtras
import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct SignUpTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  private func configureService(_ service: MockSignUpService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      signUpService: service
    )
  }

  @Test
  func updateUsesService() async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.UpdateParams)?>(nil)
    let service = MockSignUpService(update: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signUp.update(firstName: "John", lastName: "Doe")

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.firstName == "John")
    #expect(params.1.lastName == "Doe")
  }

  @Test
  func sendEmailCodeUsesService() async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.PrepareVerificationParams)?>(nil)
    let service = MockSignUpService(prepareVerification: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signUp.sendEmailCode()

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.strategy == .emailCode)
  }

  @Test
  func sendPhoneCodeUsesService() async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.PrepareVerificationParams)?>(nil)
    let service = MockSignUpService(prepareVerification: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signUp.sendPhoneCode()

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.strategy == .phoneCode)
  }

  @Test
  func verifyEmailCodeUsesService() async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.AttemptVerificationParams)?>(nil)
    let service = MockSignUpService(attemptVerification: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signUp.verifyEmailCode("123456")

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.strategy == .emailCode)
    #expect(params.1.code == "123456")
  }

  @Test
  func verifyPhoneCodeUsesService() async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.AttemptVerificationParams)?>(nil)
    let service = MockSignUpService(attemptVerification: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signUp.verifyPhoneCode("654321")

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.strategy == .phoneCode)
    #expect(params.1.code == "654321")
  }

  @Test
  func reloadUsesService() async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.GetParams)?>(nil)
    let service = MockSignUpService(get: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signUp.reload()

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.rotatingTokenNonce == nil)
  }

  @Test
  func reloadWithRotatingTokenNonceUsesService() async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.GetParams)?>(nil)
    let service = MockSignUpService(get: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signUp.reload(rotatingTokenNonce: "test_nonce")

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.rotatingTokenNonce == "test_nonce")
  }
}
