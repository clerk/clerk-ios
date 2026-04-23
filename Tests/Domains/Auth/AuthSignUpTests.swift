@testable import ClerkKit
#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
import AuthenticationServices
#endif
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct AuthSignUpTests {
  private let support = AuthTestSupport()

  @Test
  func signUpWithStandardFieldsUsesSignUpServiceCreate() async throws {
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return .mock
    })

    let clerk = try support.makeClerk(signUpService: signUpService)

    _ = try await clerk.auth.signUp(emailAddress: "test@example.com", password: "password123")

    let params = try #require(signUpParams.value)
    #expect(params.emailAddress == "test@example.com")
    #expect(params.password == "password123")
  }

  @Test
  func updateExistingSignUpUsesSignUpServiceUpdate() async throws {
    let captured = LockIsolated<(String, SignUp.UpdateParams)?>(nil)
    let signUpService = MockSignUpService(update: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    let clerk = try support.makeClerk(signUpService: signUpService)

    _ = try await clerk.auth.update(SignUp.mock, firstName: "John", lastName: "Doe")

    let params = try #require(captured.value)
    #expect(params.0 == SignUp.mock.id)
    #expect(params.1.firstName == "John")
    #expect(params.1.lastName == "Doe")
  }

  @Test
  func signUpWithOAuthUsesSignUpServiceCreate() async throws {
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

    let clerk = try support.makeClerk(signInService: signInService, signUpService: signUpService)

    do {
      _ = try await clerk.auth.signUpWithOAuth(provider: .google)
    } catch {}

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params.strategy?.rawValue == OAuthProvider.google.strategy)
  }

  @Test
  func signUpWithEnterpriseSSOUsesSignUpServiceCreate() async throws {
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

    let clerk = try support.makeClerk(signInService: signInService, signUpService: signUpService)

    do {
      _ = try await clerk.auth.signUpWithEnterpriseSSO(emailAddress: "user@enterprise.com")
    } catch {}

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params.emailAddress == "user@enterprise.com")
  }

  @Test
  func signUpWithIdTokenUsesSignUpServiceCreate() async throws {
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

    let clerk = try support.makeClerk(signInService: signInService, signUpService: signUpService)

    _ = try await clerk.auth.signUpWithIdToken("mock_id_token", provider: .apple)

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params.strategy?.rawValue == IDTokenProvider.apple.strategy)
    #expect(params.token == "mock_id_token")
  }

  @Test
  func signUpWithIdTokenPreservesEnabledNameFields() async throws {
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return .mock
    })

    let clerk = try support.makeClerk(signUpService: signUpService)

    _ = try await clerk.auth.signUpWithIdToken(
      "mock_id_token",
      provider: .apple,
      firstName: "Jane",
      lastName: "Doe"
    )

    let params = try #require(signUpParams.value)
    #expect(params.firstName == "Jane")
    #expect(params.lastName == "Doe")
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @Test
  func normalizedAppleScopesDropsFullNameWhenBothNameFieldsAreDisabled() {
    var environment = Clerk.Environment.mock
    environment.userSettings.attributes["first_name"]?.enabled = false
    environment.userSettings.attributes["last_name"]?.enabled = false

    let scopes = Auth.normalizedAppleScopes(
      [.email, .fullName],
      environment: environment
    )

    #expect(scopes == [.email])
  }

  @Test
  func normalizedAppleScopesKeepsFullNameWhenEitherNameFieldIsEnabled() {
    var environment = Clerk.Environment.mock
    environment.userSettings.attributes["first_name"]?.enabled = true
    environment.userSettings.attributes["last_name"]?.enabled = false

    let scopes = Auth.normalizedAppleScopes(
      [.email, .fullName],
      environment: environment
    )

    #expect(scopes == [.email, .fullName])
  }

  @Test
  func normalizedAppleScopesKeepsFullNameWhenEnvironmentIsUnavailable() {
    let scopes = Auth.normalizedAppleScopes(
      [.email, .fullName],
      environment: nil
    )

    #expect(scopes == [.email, .fullName])
  }
  #endif

  @Test
  func signUpWithTicketUsesSignUpServiceCreate() async throws {
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return .mock
    })

    let clerk = try support.makeClerk(signUpService: signUpService)

    _ = try await clerk.auth.signUpWithTicket("mock_ticket_value")

    let params = try #require(signUpParams.value)
    #expect(params.ticket == "mock_ticket_value")
  }
}
