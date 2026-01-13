import ConcurrencyExtras
import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct AuthTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  private func configureDependencies(
    signInService: MockSignInService? = nil,
    signUpService: MockSignUpService? = nil,
    sessionService: MockSessionService? = nil
  ) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      signInService: signInService,
      signUpService: signUpService,
      sessionService: sessionService
    )
  }

  @Test
  func signInWithIdentifierUsesSignInService() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService)

    _ = try await Clerk.shared.auth.signIn("test@example.com")

    let params = try #require(signInParams.value)
    #expect(params.identifier == "test@example.com")
  }

  @Test
  func signInWithPasswordUsesSignInService() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService)

    _ = try await Clerk.shared.auth.signInWithPassword(identifier: "test@example.com", password: "password123")

    let params = try #require(signInParams.value)
    #expect(params.identifier == "test@example.com")
    #expect(params.password == "password123")
  }

  @Test
  func signInWithOAuthUsesSignUpService() async throws {
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

    do {
      _ = try await Clerk.shared.auth.signInWithOAuth(provider: .google)
    } catch {
      // Expected to fail in unit tests due to missing external verification data.
    }

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params.strategy?.rawValue == OAuthProvider.google.strategy)
  }

  @Test
  func signInWithEnterpriseSSOUsesSignUpService() async throws {
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

    do {
      _ = try await Clerk.shared.auth.signInWithEnterpriseSSO(emailAddress: "user@enterprise.com")
    } catch {
      // Expected to fail in unit tests due to missing external verification data.
    }

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params.emailAddress == "user@enterprise.com")
  }

  @Test
  func signInWithIdTokenUsesSignInService() async throws {
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

    _ = try await Clerk.shared.auth.signInWithIdToken("mock_id_token", provider: .apple)

    #expect(signUpCalled.value == false)
    let params = try #require(signInParams.value)
    #expect(params.strategy?.rawValue == IDTokenProvider.apple.strategy)
    #expect(params.token == "mock_id_token")
  }

  @Test
  func signInWithPasskeyUsesSignInService() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService)

    _ = try await Clerk.shared.auth.signInWithPasskey()

    _ = try #require(signInParams.value)
  }

  @Test
  func signInWithTicketUsesSignInService() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService)

    _ = try await Clerk.shared.auth.signInWithTicket("mock_ticket_value")

    let params = try #require(signInParams.value)
    #expect(params.ticket == "mock_ticket_value")
  }

  @Test
  func signUpWithStandardFieldsUsesSignUpService() async throws {
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return .mock
    })

    configureDependencies(signUpService: signUpService)

    _ = try await Clerk.shared.auth.signUp(emailAddress: "test@example.com", password: "password123")

    let params = try #require(signUpParams.value)
    #expect(params.emailAddress == "test@example.com")
    #expect(params.password == "password123")
  }

  @Test
  func signUpWithOAuthUsesSignUpService() async throws {
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

    do {
      _ = try await Clerk.shared.auth.signUpWithOAuth(provider: .google)
    } catch {
      // Expected to fail in unit tests due to missing external verification data.
    }

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params.strategy?.rawValue == OAuthProvider.google.strategy)
  }

  @Test
  func signUpWithEnterpriseSSOUsesSignUpService() async throws {
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

    do {
      _ = try await Clerk.shared.auth.signUpWithEnterpriseSSO(emailAddress: "user@enterprise.com")
    } catch {
      // Expected to fail in unit tests due to missing external verification data.
    }

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params.emailAddress == "user@enterprise.com")
  }

  @Test
  func signUpWithIdTokenUsesSignUpService() async throws {
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

    _ = try await Clerk.shared.auth.signUpWithIdToken("mock_id_token", provider: .apple)

    #expect(signInCalled.value == false)
    let params = try #require(signUpParams.value)
    #expect(params.strategy?.rawValue == IDTokenProvider.apple.strategy)
    #expect(params.token == "mock_id_token")
  }

  @Test
  func signUpWithTicketUsesSignUpService() async throws {
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return .mock
    })

    configureDependencies(signUpService: signUpService)

    _ = try await Clerk.shared.auth.signUpWithTicket("mock_ticket_value")

    let params = try #require(signUpParams.value)
    #expect(params.ticket == "mock_ticket_value")
  }

  @Test
  func signOutUsesSessionService() async throws {
    let signOutSessionId = LockIsolated<String?>(nil)
    let sessionService = MockSessionService(signOut: { sessionId in
      signOutSessionId.setValue(sessionId)
    })

    configureDependencies(sessionService: sessionService)

    try await Clerk.shared.auth.signOut()

    #expect(signOutSessionId.value == nil)
  }

  @Test
  func signOutWithSessionIdUsesSessionService() async throws {
    let signOutSessionId = LockIsolated<String?>(nil)
    let sessionService = MockSessionService(signOut: { sessionId in
      signOutSessionId.setValue(sessionId)
    })

    configureDependencies(sessionService: sessionService)

    try await Clerk.shared.auth.signOut(sessionId: "sess_test123")

    #expect(signOutSessionId.value == "sess_test123")
  }

  @Test
  func setActiveUsesSessionService() async throws {
    let activeParams = LockIsolated<(String, String?)?>(nil)
    let sessionService = MockSessionService(setActive: { sessionId, organizationId in
      activeParams.setValue((sessionId, organizationId))
    })

    configureDependencies(sessionService: sessionService)

    try await Clerk.shared.auth.setActive(sessionId: "sess_test123")

    let params = try #require(activeParams.value)
    #expect(params.0 == "sess_test123")
    #expect(params.1 == nil)
  }

  @Test
  func setActiveWithOrganizationIdUsesSessionService() async throws {
    let activeParams = LockIsolated<(String, String?)?>(nil)
    let sessionService = MockSessionService(setActive: { sessionId, organizationId in
      activeParams.setValue((sessionId, organizationId))
    })

    configureDependencies(sessionService: sessionService)

    try await Clerk.shared.auth.setActive(sessionId: "sess_test123", organizationId: "org_test456")

    let params = try #require(activeParams.value)
    #expect(params.0 == "sess_test123")
    #expect(params.1 == "org_test456")
  }
}
