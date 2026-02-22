@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct SessionTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  private func createSession(
    status: Session.SessionStatus,
    tasks: [Session.Task]? = nil
  ) -> Session {
    let date = Date(timeIntervalSince1970: 1_609_459_200)
    return Session(
      id: "sess_test",
      status: status,
      expireAt: date,
      abandonAt: date,
      lastActiveAt: date,
      createdAt: date,
      updatedAt: date,
      tasks: tasks
    )
  }

  @Test
  func revokeUsesSessionServiceRevoke() async throws {
    let session = Session.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockSessionService(revoke: { sessionId in
      captured.setValue(sessionId)
      return .mock
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      sessionService: service
    )

    _ = try await session.revoke()

    #expect(captured.value == session.id)
  }

  @Test
  func taskKeyParsesSetupMfa() {
    let task = Session.Task(key: "setup-mfa")
    #expect(task == .setupMfa)
  }

  @Test
  func taskKeyParsesUnknownTask() {
    let task = Session.Task(key: "another-task")
    #expect(task == .unknown("another-task"))
  }

  @Test
  func requiresForcedMfaOnlyForPendingSetupMfa() {
    let pendingSession = createSession(status: .pending, tasks: [.init(key: "setup-mfa")])
    let activeSession = createSession(status: .active, tasks: [.init(key: "setup-mfa")])

    #expect(pendingSession.requiresForcedMfa == true)
    #expect(activeSession.requiresForcedMfa == false)
  }
}
