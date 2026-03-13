#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct AuthNavigationTests {
  @Test
  func handleSessionTaskCompletionRoutesToCurrentFirstPendingTask() {
    let navigation = AuthNavigation()
    let session = session(pendingTasks: [.setupMfa, .resetPassword])

    navigation.handleSessionTaskCompletion(session: session)

    #expect(navigation.path == [.sessionTaskStart(task: .setupMfa)])
    #expect(navigation.allTasksComplete == false)
  }

  @Test
  func handleSessionTaskCompletionMarksAllTasksCompleteWhenSessionHasNoPendingTasks() {
    let navigation = AuthNavigation()
    let session = session(pendingTasks: [])

    navigation.handleSessionTaskCompletion(session: session)

    #expect(navigation.path.isEmpty)
    #expect(navigation.allTasksComplete)
  }

  private func session(pendingTasks: [Session.Task]) -> Session {
    var session = Session.mock
    session.tasks = pendingTasks
    return session
  }
}

#endif
