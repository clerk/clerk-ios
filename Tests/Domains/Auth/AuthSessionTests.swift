@testable import ClerkKit
import ConcurrencyExtras
import Testing

@MainActor
@Suite(.tags(.unit))
struct AuthSessionTests {
  private let support = AuthTestSupport()

  @Test(
    arguments: [
      AuthSignOutScenario(sessionId: nil),
      AuthSignOutScenario(sessionId: "sess_test123"),
    ]
  )
  func signOutUsesSessionServiceSignOut(
    scenario: AuthSignOutScenario
  ) async throws {
    let signOutSessionId = LockIsolated<String?>(nil)
    let sessionService = MockSessionService(signOut: { sessionId in
      signOutSessionId.setValue(sessionId)
    })

    let clerk = try support.makeClerk(sessionService: sessionService)

    try await clerk.auth.signOut(sessionId: scenario.sessionId)

    #expect(signOutSessionId.value == scenario.sessionId)
  }

  @Test(
    arguments: [
      AuthSetActiveScenario(organizationId: nil),
      AuthSetActiveScenario(organizationId: "org_test456"),
    ]
  )
  func setActiveUsesSessionServiceSetActive(
    scenario: AuthSetActiveScenario
  ) async throws {
    let activeParams = LockIsolated<(String, String?)?>(nil)
    let sessionService = MockSessionService(setActive: { sessionId, organizationId in
      activeParams.setValue((sessionId, organizationId))
    })

    let clerk = try support.makeClerk(sessionService: sessionService)

    try await clerk.auth.setActive(
      sessionId: "sess_test123",
      organizationId: scenario.organizationId
    )

    let params = try #require(activeParams.value)
    #expect(params.0 == "sess_test123")
    #expect(params.1 == scenario.organizationId)
  }

  @Test
  func revokeExistingSessionUsesSessionServiceRevoke() async throws {
    let captured = LockIsolated<(String, String?)?>(nil)
    let sessionService = MockSessionService(revoke: { sessionId, actingSessionId in
      captured.setValue((sessionId, actingSessionId))
      return .mock
    })

    let clerk = try support.makeClerk(sessionService: sessionService)
    clerk.client = .mock

    _ = try await clerk.auth.revoke(Session.mock2)

    let params = try #require(captured.value)
    #expect(params.0 == Session.mock2.id)
    #expect(params.1 == clerk.session?.id)
  }
}
