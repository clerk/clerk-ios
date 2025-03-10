import ConcurrencyExtras
import Factory
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
  
  @MainActor
  @Test func testConfigureWithInvalidKey() async throws {
    let clerk = Clerk()
    clerk.configure(publishableKey: "     ")
    #expect(clerk.publishableKey == "")
  }
  
}

@Suite(.serialized) struct ClerkSerializedTests {
      
  init() {
    Container.shared.reset()
  }
  
  @MainActor
  @Test func testClientIdSavedToKeychainOnClientDidSet() throws {
    let clientIdInKeychain = LockIsolated<String?>(nil)
    Container.shared.clerkService.register {
      var mock = ClerkService.liveValue
      mock.saveClientIdToKeychain = { clientIdInKeychain.setValue($0) }
      return mock
    }
    let clerk = Clerk()
    clerk.client = .mock
    #expect(clientIdInKeychain.value == Client.mock.id)
  }
  
  @MainActor
  @Test func testLoadWithInvalidKey() async throws {
    let clerk = Clerk()
    clerk.configure(publishableKey: "     ")
    await #expect(throws: Error.self) {
      try await clerk.load()
    }
  }
  
  @MainActor
  @Test func testLoadingStateSetAfterLoadWithValidKey() async throws {
    try await withMainSerialExecutor {
      let task = Task {
        Container.shared.environmentService.register { .init(get: { .init() }) }
        Container.shared.clientService.register { .init(get: { .mock }) }
        let clerk = Clerk()
        clerk.configure(publishableKey: "pk_test_")
        try await clerk.load()
        #expect(clerk.isLoaded)
      }
      
      try await task.value
    }
  }
  
  @MainActor
  @Test func testLoadThrowsWhenClerkGetThrows() async throws {
    await withMainSerialExecutor {
      let task = Task {
        Container.shared.environmentService.register { .init(get: { .init() }) }
        Container.shared.clientService.register { .init(get: { throw ClerkAPIError.mock }) }
        let clerk = Clerk()
        clerk.configure(publishableKey: "pk_test_")
        await #expect(throws: Error.self, performing: {
          try await clerk.load()
        })
        #expect(!clerk.isLoaded)
      }
      
      await task.value
    }
  }
  
  @MainActor
  @Test func testLoadThrowsWhenEnvironmentGetThrows() async throws {
    await withMainSerialExecutor {
      let task = Task {
        Container.shared.environmentService.register { .init(get: { throw ClerkAPIError.mock }) }
        Container.shared.clientService.register { .init(get: { .mock }) }
        let clerk = Clerk()
        clerk.configure(publishableKey: "pk_test_")
        await #expect(throws: Error.self, performing: {
          try await clerk.load()
        })
        #expect(!clerk.isLoaded)
      }
      
      await task.value
    }
  }
  
  @MainActor
  @Test func testSignOutRequest() async throws {
    let clerk = Clerk()
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sessions")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Client>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()
    try await clerk.signOut()
    #expect(requestHandled.value)
  }
  
  @MainActor
  @Test func testSignOutWithSessionIdRequest() async throws {
    let clerk = Clerk()
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sessions/\(Session.mock.id)/remove")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Session>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()
    try await clerk.signOut(sessionId: Session.mock.id)
    #expect(requestHandled.value)
  }
  
  @MainActor
  @Test func testSetActiveRequest() async throws {
    let clerk = Clerk()
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sessions/\(Session.mock.id)/touch")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Session>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()
    try await clerk.setActive(sessionId: Session.mock.id)
    #expect(requestHandled.value)
  }
  
  
}
