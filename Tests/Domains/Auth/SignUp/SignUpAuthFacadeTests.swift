@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct SignUpAuthFacadeTests {
  private let support = AuthTestSupport()

  struct ReloadScenario: Codable, Equatable {
    let rotatingTokenNonce: String?
  }

  @Test
  func updateUsesSignUpServiceUpdate() async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.UpdateParams)?>(nil)
    let service = MockSignUpService(update: { id, params in
      captured.setValue((id, params))
      return .mock
    })
    let clerk = try support.makeClerk(signUpService: service)

    _ = try await clerk.auth.update(signUp, firstName: "John", lastName: "Doe")

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.firstName == "John")
    #expect(params.1.lastName == "Doe")
  }

  @Test
  func sendEmailCodeUsesSignUpServicePrepareVerification() async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.PrepareVerificationParams)?>(nil)
    let service = MockSignUpService(prepareVerification: { id, params in
      captured.setValue((id, params))
      return .mock
    })
    let clerk = try support.makeClerk(signUpService: service)

    _ = try await clerk.auth.sendEmailCode(for: signUp)

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.strategy == .emailCode)
  }

  @Test
  func sendPhoneCodeUsesSignUpServicePrepareVerification() async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.PrepareVerificationParams)?>(nil)
    let service = MockSignUpService(prepareVerification: { id, params in
      captured.setValue((id, params))
      return .mock
    })
    let clerk = try support.makeClerk(signUpService: service)

    _ = try await clerk.auth.sendPhoneCode(for: signUp)

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.strategy == .phoneCode)
  }

  @Test
  func verifyEmailCodeUsesSignUpServiceAttemptVerification() async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.AttemptVerificationParams)?>(nil)
    let service = MockSignUpService(attemptVerification: { id, params in
      captured.setValue((id, params))
      return .mock
    })
    let clerk = try support.makeClerk(signUpService: service)

    _ = try await clerk.auth.verifyEmailCode("123456", for: signUp)

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.strategy == .emailCode)
    #expect(params.1.code == "123456")
  }

  @Test
  func verifyPhoneCodeUsesSignUpServiceAttemptVerification() async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.AttemptVerificationParams)?>(nil)
    let service = MockSignUpService(attemptVerification: { id, params in
      captured.setValue((id, params))
      return .mock
    })
    let clerk = try support.makeClerk(signUpService: service)

    _ = try await clerk.auth.verifyPhoneCode("654321", for: signUp)

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.strategy == .phoneCode)
    #expect(params.1.code == "654321")
  }

  @Test(
    arguments: [
      ReloadScenario(rotatingTokenNonce: nil),
      ReloadScenario(rotatingTokenNonce: "test_nonce"),
    ]
  )
  func reloadUsesSignUpServiceGet(
    scenario: ReloadScenario
  ) async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.GetParams)?>(nil)
    let service = MockSignUpService(get: { id, params in
      captured.setValue((id, params))
      return .mock
    })
    let clerk = try support.makeClerk(signUpService: service)

    _ = try await clerk.auth.reload(signUp, rotatingTokenNonce: scenario.rotatingTokenNonce)

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.rotatingTokenNonce == scenario.rotatingTokenNonce)
  }

  @Test
  func handleTransferFlowUsesInjectedSignInService() async throws {
    var signUp = SignUp.mock
    signUp.verifications["external_account"] = Verification(
      status: .transferable,
      strategy: .oauth(.google)
    )

    let captured = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      captured.setValue(params)
      return .mock
    })
    let clerk = try support.makeClerk(signInService: signInService)

    let result = try await clerk.auth.handleTransferFlow(for: signUp)

    let signIn = try #require({
      if case .signIn(let signIn) = result {
        return signIn
      }
      return nil
    }())

    let params = try #require(captured.value)
    #expect(params.transfer == true)
    #expect(signIn.id == SignIn.mock.id)
  }
}
