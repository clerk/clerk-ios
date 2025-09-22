import ConcurrencyExtras
import FactoryKit
import Foundation
import Mocker
import Testing

@testable import Clerk

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
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Client>(response: .mockSignedOut, client: .mockSignedOut))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()
    try await clerk.signOut()
    #expect(requestHandled.value)
    let event = await eventTask.value
    var didReceiveSignedOutEvent = false
    if case .signedOut? = event {
      didReceiveSignedOutEvent = true
    }
    #expect(didReceiveSignedOutEvent)
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
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: .mock, client: .mockSignedOut))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()
    try await clerk.signOut(sessionId: Session.mock.id)
    #expect(requestHandled.value)
    let event = await eventTask.value
    var didReceiveSignedOutEvent = false
    if case .signedOut? = event {
      didReceiveSignedOutEvent = true
    }
    #expect(didReceiveSignedOutEvent)
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
