@testable import ClerkKit
import Testing

@MainActor
struct AuthTestSupport {
  let fixture = ClerkTestFixture()

  func makeClerk(
    signInService: MockSignInService? = nil,
    signUpService: MockSignUpService? = nil,
    sessionService: MockSessionService? = nil,
    environment: Clerk.Environment? = .mock,
    options: Clerk.Options = .init()
  ) throws -> Clerk {
    try fixture.makeClerk(
      signInService: signInService,
      signUpService: signUpService,
      sessionService: sessionService,
      options: options,
      environment: environment
    )
  }
}

struct AuthSignOutScenario: Codable, Equatable {
  let sessionId: String?
}

struct AuthSetActiveScenario: Codable, Equatable {
  let organizationId: String?
}
