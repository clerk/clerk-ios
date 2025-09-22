import ConcurrencyExtras
import FactoryKit
import Foundation
import Mocker
import Testing

@testable import Clerk

private let signedOutSession: Session = {
  var session = Session.mock
  session.status = .removed
  return session
}()

// Any test that accesses Container.shared or performs networking
// should be placed in the serialized tests below

struct ClerkTests {

  @MainActor
  @Test func testInstanceType() async throws {
    let clerk = Clerk()
    clerk.configure(publishableKey: "pk_test_123456789")
    #expect(clerk.instanceType == .development)
    clerk.configure(publishableKey: "pk_live_123456789")
    #expect(clerk.instanceType == .production)
  }

  @MainActor
  @Test func testUserShortcut() async throws {
    let clerk = Clerk()
    #expect(clerk.user == nil)
    clerk.client = Client.mock
    #expect(clerk.user?.id == User.mock.id)
  }

  @MainActor
  @Test func testSessionShortcut() async throws {
    let clerk = Clerk()
    #expect(clerk.session == nil)
    clerk.client = Client.mock
    #expect(clerk.session?.id == Session.mock.id)
  }

  @MainActor
  @Test func testLogsWhenLastActiveSessionPending() async throws {
    let clerk = Clerk()
    var pendingSession = Session.mock
    pendingSession.id = "pending-1"
    pendingSession.status = .pending
    pendingSession.tasks = [.init(key: "task-a")]

    var clientV1 = Client.mock
    clientV1.sessions = [pendingSession]
    clientV1.lastActiveSessionId = pendingSession.id

    var pendingSessionUpdated = pendingSession
    pendingSessionUpdated.tasks = [.init(key: "task-b")]

    var clientV2 = Client.mock
    clientV2.sessions = [pendingSessionUpdated]
    clientV2.lastActiveSessionId = pendingSessionUpdated.id

    #expect(clerk.shouldLogPendingSessionStatus(previousClient: nil, currentClient: clientV1))
    #expect(!clerk.shouldLogPendingSessionStatus(previousClient: clientV1, currentClient: clientV1))
    #expect(clerk.shouldLogPendingSessionStatus(previousClient: clientV1, currentClient: clientV2))
  }

  @MainActor
  @Test func testSkipsWhenLastActiveSessionActive() async throws {
    let clerk = Clerk()
    var activeSession = Session.mock
    activeSession.id = "session-1"
    activeSession.status = .active

    var client = Client.mock
    client.sessions = [activeSession]
    client.lastActiveSessionId = activeSession.id

    #expect(!clerk.shouldLogPendingSessionStatus(previousClient: nil, currentClient: client))
  }

  @MainActor
  @Test func testSkipsWhenLastActiveSessionMissing() async throws {
    let clerk = Clerk()
    var pendingSession = Session.mock
    pendingSession.id = "pending-1"
    pendingSession.status = .pending

    var client = Client.mock
    client.sessions = [pendingSession]
    client.lastActiveSessionId = "unknown"

    #expect(!clerk.shouldLogPendingSessionStatus(previousClient: nil, currentClient: client))
  }

  @MainActor
  @Test func testSkipsWhenLastActiveSessionNotSet() async throws {
    let clerk = Clerk()
    var pendingSession = Session.mock
    pendingSession.status = .pending

    var client = Client.mock
    client.sessions = [pendingSession]
    client.lastActiveSessionId = nil

    #expect(!clerk.shouldLogPendingSessionStatus(previousClient: nil, currentClient: client))
  }

  @MainActor
  @Test func testLogsAgainAfterPendingSessionResolves() async throws {
    let clerk = Clerk()
    var pendingSession = Session.mock
    pendingSession.id = "session-1"
    pendingSession.status = .pending

    var activeSession = Session.mock
    activeSession.id = "session-1"
    activeSession.status = .active

    var pendingClientV1 = Client.mock
    pendingClientV1.sessions = [pendingSession]
    pendingClientV1.lastActiveSessionId = pendingSession.id

    var activeClient = Client.mock
    activeClient.sessions = [activeSession]
    activeClient.lastActiveSessionId = activeSession.id

    var pendingSessionWithTasks = pendingSession
    pendingSessionWithTasks.tasks = [.init(key: "task-a")]

    var pendingClientV2 = Client.mock
    pendingClientV2.sessions = [pendingSessionWithTasks]
    pendingClientV2.lastActiveSessionId = pendingSessionWithTasks.id

    var pendingSessionWithDifferentTasks = pendingSessionWithTasks
    pendingSessionWithDifferentTasks.tasks = [.init(key: "task-b")]

    var pendingClientV3 = Client.mock
    pendingClientV3.sessions = [pendingSessionWithDifferentTasks]
    pendingClientV3.lastActiveSessionId = pendingSessionWithDifferentTasks.id

    #expect(clerk.shouldLogPendingSessionStatus(previousClient: nil, currentClient: pendingClientV1))
    #expect(!clerk.shouldLogPendingSessionStatus(previousClient: pendingClientV1, currentClient: pendingClientV1))
    #expect(!clerk.shouldLogPendingSessionStatus(previousClient: pendingClientV1, currentClient: activeClient))
    #expect(clerk.shouldLogPendingSessionStatus(previousClient: activeClient, currentClient: pendingClientV2))
    #expect(!clerk.shouldLogPendingSessionStatus(previousClient: pendingClientV2, currentClient: pendingClientV2))
    #expect(clerk.shouldLogPendingSessionStatus(previousClient: pendingClientV2, currentClient: pendingClientV3))
  }

}

@Suite(.serialized) final class ClerkSerializedTests {

  init() {
    Container.shared.reset()
  }

  @MainActor
  @Test func testLoadWithInvalidKey() async throws {
    let clerk = Clerk()
    clerk.configure(publishableKey: "     ")
    try await clerk.load()
    #expect(!clerk.isLoaded)
  }

//  @MainActor
//  @Test func testLoadingStateSetAfterLoadWithValidKey() async throws {
//    try await withMainSerialExecutor {
//      let task = Task {
//        Container.shared.environmentService.register { .init(get: { .init() }) }
//        Container.shared.clientService.register { .init(get: { .mock }) }
//        let clerk = Clerk()
//        clerk.configure(publishableKey: "pk_test_")
//        try await clerk.load()
//        #expect(clerk.isLoaded)
//      }
//
//      try await task.value
//    }
//  }

  @MainActor
  @Test func testSignOutRequest() async throws {
    let clerk = Clerk.shared
    clerk.client = .mock
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sessions")
    let eventTask = Task<AuthEvent?, Never> { @MainActor in
      for await event in clerk.authEventEmitter.events {
        if case .signedOut = event {
          return event
        }
      }
      return nil
    }
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: signedOutSession, client: .mockSignedOut))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()
    try await clerk.signOut()
    #expect(requestHandled.value)
    let event = await eventTask.value
    guard case let .signedOut(session: eventSession)? = event else {
      Issue.record("Expected signedOut auth event")
      return
    }
    #expect(eventSession.id == signedOutSession.id)
    #expect(eventSession.status == .removed)
  }

  @MainActor
  @Test func testSignOutWithSessionIdRequest() async throws {
    let clerk = Clerk.shared
    clerk.client = .mock
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sessions/\(Session.mock.id)/remove")
    let eventTask = Task<AuthEvent?, Never> { @MainActor in
      for await event in clerk.authEventEmitter.events {
        if case .signedOut = event {
          return event
        }
      }
      return nil
    }
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: signedOutSession, client: .mockSignedOut))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()
    try await clerk.signOut(sessionId: Session.mock.id)
    #expect(requestHandled.value)
    let event = await eventTask.value
    guard case let .signedOut(session: eventSession)? = event else {
      Issue.record("Expected signedOut auth event")
      return
    }
    #expect(eventSession.id == signedOutSession.id)
    #expect(eventSession.status == .removed)
}

  @MainActor
  @Test(
    "Set Active Tests",
    arguments: [
      "1", nil
    ]) func testSetActiveRequest(organizationId: String?) async throws
  {
    let clerk = Clerk()
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sessions/\(Session.mock.id)/touch")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["active_organization_id"] == organizationId)
      requestHandled.setValue(true)
    }
    mock.register()
    try await clerk.setActive(sessionId: Session.mock.id, organizationId: organizationId)
    #expect(requestHandled.value)
  }

}
