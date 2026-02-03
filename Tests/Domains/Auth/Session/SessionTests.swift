import ConcurrencyExtras
import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct SessionTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
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
  func currentTask_ReturnsFirstTask() {
    let date = Date(timeIntervalSince1970: 1_609_459_200)
    let session = Session(
      id: "session1",
      status: .pending,
      expireAt: date,
      abandonAt: date,
      lastActiveAt: date,
      createdAt: date,
      updatedAt: date,
      tasks: [
        Session.Task(key: "setup-mfa"),
        Session.Task(key: "reset-password"),
      ]
    )

    #expect(session.currentTask?.key == "setup-mfa")
  }

  @Test
  func currentTask_ReturnsNilWhenNoTasks() {
    let date = Date(timeIntervalSince1970: 1_609_459_200)
    let session = Session(
      id: "session1",
      status: .pending,
      expireAt: date,
      abandonAt: date,
      lastActiveAt: date,
      createdAt: date,
      updatedAt: date,
      tasks: nil
    )

    #expect(session.currentTask == nil)
  }
}
