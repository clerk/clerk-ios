@testable import ClerkKit
#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
import AuthenticationServices
#endif
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct AuthTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  private func configureDependencies(
    signInService: MockSignInService? = nil,
    signUpService: MockSignUpService? = nil,
    sessionService: MockSessionService? = nil,
    environment: Clerk.Environment? = .mock
  ) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      signInService: signInService,
      signUpService: signUpService,
      sessionService: sessionService
    )
    Clerk.shared.environment = environment
  }

  struct SignOutScenario: Codable, Equatable {
    let sessionId: String?
  }

  struct SetActiveScenario: Codable, Equatable {
    let organizationId: String?
  }

  @Test
  func signInWithIdentifierUsesSignInServiceCreate() async throws {
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
  func signInWithPasswordUsesSignInServiceCreate() async throws {
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

    configureDependencies(signInService: signInService, signUpService: signUpService)

    do {
      _ = try await Clerk.shared.auth.signInWithOAuth(provider: .google)
    } catch {
      // Expected to fail in unit tests due to missing external verification data.
    }

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

    configureDependencies(signInService: signInService, signUpService: signUpService)

    do {
      _ = try await Clerk.shared.auth.signInWithEnterpriseSSO(emailAddress: "user@enterprise.com")
    } catch {
      // Expected to fail in unit tests due to missing external verification data.
    }

    #expect(signUpCalled.value == false)
    let params = try #require(signInParams.value)
    #expect(params.identifier == "user@enterprise.com")
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

    configureDependencies(signInService: signInService, signUpService: signUpService)

    _ = try await Clerk.shared.auth.signInWithIdToken("mock_id_token", provider: .apple)

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

    let signInService = MockSignInService(create: { _ in
      signIn
    })
    let signUpService = MockSignUpService(create: { _ in
      signUpCalled.setValue(true)
      return .mock
    })

    configureDependencies(signInService: signInService, signUpService: signUpService)

    do {
      _ = try await Clerk.shared.auth.signInWithIdToken(
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

    configureDependencies(signInService: signInService)

    do {
      _ = try await Clerk.shared.auth.signInWithPasskey()
    } catch {
      // Expected to fail in unit tests because no passkey challenge/credential is available.
    }

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

    configureDependencies(signInService: signInService)

    _ = try await Clerk.shared.auth.signInWithTicket("mock_ticket_value")

    let params = try #require(signInParams.value)
    #expect(params.ticket == "mock_ticket_value")
  }

  @Test
  func signUpWithStandardFieldsUsesSignUpServiceCreate() async throws {
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

    configureDependencies(signInService: signInService, signUpService: signUpService)

    _ = try await Clerk.shared.auth.signUpWithIdToken("mock_id_token", provider: .apple)

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

    configureDependencies(signUpService: signUpService)

    _ = try await Clerk.shared.auth.signUpWithIdToken(
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

    configureDependencies(signUpService: signUpService)

    _ = try await Clerk.shared.auth.signUpWithTicket("mock_ticket_value")

    let params = try #require(signUpParams.value)
    #expect(params.ticket == "mock_ticket_value")
  }

  @Test(
    arguments: [
      SignOutScenario(sessionId: nil),
      SignOutScenario(sessionId: "sess_test123"),
    ]
  )
  func signOutUsesSessionServiceSignOut(
    scenario: SignOutScenario
  ) async throws {
    let signOutSessionId = LockIsolated<String?>(nil)
    let sessionService = MockSessionService(signOut: { sessionId in
      signOutSessionId.setValue(sessionId)
    })

    configureDependencies(sessionService: sessionService)

    try await Clerk.shared.auth.signOut(sessionId: scenario.sessionId)

    #expect(signOutSessionId.value == scenario.sessionId)
  }

  @Test(
    arguments: [
      SetActiveScenario(organizationId: nil),
      SetActiveScenario(organizationId: "org_test456"),
    ]
  )
  func setActiveUsesSessionServiceSetActive(
    scenario: SetActiveScenario
  ) async throws {
    let activeParams = LockIsolated<(String, String?)?>(nil)
    let sessionService = MockSessionService(setActive: { sessionId, organizationId in
      activeParams.setValue((sessionId, organizationId))
    })

    configureDependencies(sessionService: sessionService)

    try await Clerk.shared.auth.setActive(
      sessionId: "sess_test123",
      organizationId: scenario.organizationId
    )

    let params = try #require(activeParams.value)
    #expect(params.0 == "sess_test123")
    #expect(params.1 == scenario.organizationId)
  }

  @Test
  func signInWithEmailCodeUsesSignInServiceCreate() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService)

    _ = try await Clerk.shared.auth.signInWithEmailCode(emailAddress: "test@example.com")

    let params = try #require(signInParams.value)
    #expect(params.identifier == "test@example.com")
    #expect(params.strategy == .emailCode)
  }

  @Test
  func signInWithPhoneCodeUsesSignInServiceCreate() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService)

    _ = try await Clerk.shared.auth.signInWithPhoneCode(phoneNumber: "+15551234567")

    let params = try #require(signInParams.value)
    #expect(params.identifier == "+15551234567")
    #expect(params.strategy == .phoneCode)
  }

  @Test
  func signUpWithAppleDelegatesToSignInWithApple() async throws {
    // signUpWithApple should delegate to signInWithApple with transferable flow
    // We can't fully test the Apple flow without mocking AuthenticationServices,
    // but we can verify it attempts to create a sign-in with the Apple strategy
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService)

    do {
      _ = try await Clerk.shared.auth.signUpWithApple()
    } catch {
      // Expected to fail in unit tests due to missing Apple credential
    }

    // Verify that a sign-in creation was attempted
    // (signUpWithApple delegates to signInWithApple which creates a sign-in)
    #expect(signInParams.value != nil)
  }

  @Test
  func currentSignInReturnsClientSignIn() async throws {
    var mockClient = Client.mock
    mockClient.signIn = .mock
    Clerk.shared.client = mockClient

    let currentSignIn = Clerk.shared.auth.currentSignIn

    #expect(currentSignIn?.id == SignIn.mock.id)
  }

  @Test
  func currentSignInReturnsNilWhenNoClient() async throws {
    Clerk.shared.client = nil

    let currentSignIn = Clerk.shared.auth.currentSignIn

    #expect(currentSignIn == nil)
  }

  @Test
  func currentSignUpReturnsClientSignUp() async throws {
    var mockClient = Client.mock
    mockClient.signUp = .mock
    Clerk.shared.client = mockClient

    let currentSignUp = Clerk.shared.auth.currentSignUp

    #expect(currentSignUp?.id == SignUp.mock.id)
  }

  @Test
  func currentSignUpReturnsNilWhenNoClient() async throws {
    Clerk.shared.client = nil

    let currentSignUp = Clerk.shared.auth.currentSignUp

    #expect(currentSignUp == nil)
  }

  @Test
  func sessionsReturnsClientSessions() async throws {
    var mockClient = Client.mock
    mockClient.sessions = [.mock, .mock]
    Clerk.shared.client = mockClient

    let sessions = Clerk.shared.auth.sessions

    #expect(sessions.count == 2)
  }

  @Test
  func sessionsReturnsEmptyArrayWhenNoClient() async throws {
    Clerk.shared.client = nil

    let sessions = Clerk.shared.auth.sessions

    #expect(sessions.isEmpty)
  }

  @Test
  func getTokenReturnsNilWhenNoSession() async throws {
    Clerk.shared.session = nil

    let token = try await Clerk.shared.auth.getToken()

    #expect(token == nil)
  }

  @Test
  func getTokenReturnsSessionToken() async throws {
    var mockSession = Session.mock
    mockSession.lastActiveToken = Token(jwt: "mock_jwt_token")
    Clerk.shared.session = mockSession

    let token = try await Clerk.shared.auth.getToken()

    #expect(token == "mock_jwt_token")
  }

  @Test
  func revokeSessionUsesSessionServiceRevoke() async throws {
    let revokedSessionId = LockIsolated<String?>(nil)
    let sessionService = MockSessionService(revoke: { sessionId in
      revokedSessionId.setValue(sessionId)
      return .mock
    })

    configureDependencies(sessionService: sessionService)

    var session = Session.mock
    session.id = "sess_to_revoke"
    _ = try await Clerk.shared.auth.revokeSession(session)

    #expect(revokedSessionId.value == "sess_to_revoke")
  }

  @Test
  func eventsStreamEmitsAuthEvents() async throws {
    configureDependencies()

    // Collect events in a task
    let receivedEvents = LockIsolated<[AuthEvent]>([])

    let eventCollectionTask = Task {
      var count = 0
      for await event in Clerk.shared.auth.events {
        receivedEvents.withValue { $0.append(event) }
        count += 1
        if count == 2 {
          break
        }
      }
    }

    // Give the stream time to set up
    try await Task.sleep(for: .milliseconds(50))

    // Emit test events
    Clerk.shared.auth.send(.signInCompleted(.mock))
    Clerk.shared.auth.send(.signUpCompleted(.mock))

    // Wait for events to be collected with timeout
    try await Task.sleep(for: .milliseconds(100))
    eventCollectionTask.cancel()

    let events = receivedEvents.value
    #expect(events.count == 2)
    if events.count >= 2 {
      if case .signInCompleted(let signIn) = events[0] {
        #expect(signIn.id == SignIn.mock.id)
      } else {
        #expect(Bool(false), "First event should be signInCompleted")
      }
      if case .signUpCompleted(let signUp) = events[1] {
        #expect(signUp.id == SignUp.mock.id)
      } else {
        #expect(Bool(false), "Second event should be signUpCompleted")
      }
    }
  }

  @Test
  func signInWithAppleNonTransferableThrowsOnError() async throws {
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(
      status: .transferable,
      strategy: .idToken(.apple),
      error: .mock
    )

    let signInService = MockSignInService(create: { _ in
      signIn
    })

    configureDependencies(signInService: signInService)

    let didThrow = LockIsolated(false)

    do {
      _ = try await Clerk.shared.auth.signInWithApple(transferable: false)
    } catch {
      didThrow.setValue(true)
    }

    // Should throw because transferable=false and there's an error in firstFactorVerification
    #expect(didThrow.value == true)
  }

  @Test
  func signInWithPasswordHandlesEmptyPassword() async throws {
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return .mock
    })

    configureDependencies(signInService: signInService)

    _ = try await Clerk.shared.auth.signInWithPassword(identifier: "test@example.com", password: "")

    let params = try #require(signInParams.value)
    #expect(params.password == "")
  }

  @Test
  func signUpWithAllFieldsPopulatesParams() async throws {
    let signUpParams = LockIsolated<SignUp.CreateParams?>(nil)
    let signUpService = MockSignUpService(create: { params in
      signUpParams.setValue(params)
      return .mock
    })

    configureDependencies(signUpService: signUpService)

    _ = try await Clerk.shared.auth.signUp(
      emailAddress: "test@example.com",
      password: "password123",
      firstName: "John",
      lastName: "Doe",
      username: "johndoe",
      phoneNumber: "+15551234567",
      unsafeMetadata: ["custom": "data"],
      legalAccepted: true
    )

    let params = try #require(signUpParams.value)
    #expect(params.emailAddress == "test@example.com")
    #expect(params.password == "password123")
    #expect(params.firstName == "John")
    #expect(params.lastName == "Doe")
    #expect(params.username == "johndoe")
    #expect(params.phoneNumber == "+15551234567")
    #expect(params.legalAccepted == true)
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @Test
  func normalizedAppleScopesKeepsBothWhenLastNameEnabled() {
    var environment = Clerk.Environment.mock
    environment.userSettings.attributes["first_name"]?.enabled = false
    environment.userSettings.attributes["last_name"]?.enabled = true

    let scopes = Auth.normalizedAppleScopes(
      [.email, .fullName],
      environment: environment
    )

    #expect(scopes == [.email, .fullName])
  }

  @Test
  func normalizedAppleScopesWithoutFullNameInRequest() {
    var environment = Clerk.Environment.mock
    environment.userSettings.attributes["first_name"]?.enabled = false
    environment.userSettings.attributes["last_name"]?.enabled = false

    let scopes = Auth.normalizedAppleScopes(
      [.email],
      environment: environment
    )

    // Should return as-is if fullName is not requested
    #expect(scopes == [.email])
  }
  #endif
}