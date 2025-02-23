import Testing
import Foundation
import Mocker

@testable import Clerk
@testable import Dependencies
@testable import Get
@testable import ConcurrencyExtras

extension APIClient {

  static let mockBaseUrl = URL(string: "https://clerk.mock.dev")!

  static let mock: APIClient = .init(
    baseURL: mockBaseUrl,
    { configuration in
      configuration.decoder = .clerkDecoder
      configuration.encoder = .clerkEncoder
      configuration.delegate = ClerkAPIClientDelegate()
      configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
    }
  )

}

struct ClerkTests {
  
  let clerk: Clerk
  
  init() {
    self.clerk = Clerk()
    prepareDependencies {
      $0.apiClientProvider = .init(current: { .mock }, client: { _ in  .mock })
    }
  }
  
  @MainActor
  @Test func testInstanceType() async throws {
    clerk.configure(publishableKey: "pk_test_123456789")
    #expect(clerk.instanceType == .development)
    
    clerk.configure(publishableKey: "pk_live_123456789")
    #expect(clerk.instanceType == .production)
  }
  
  @MainActor
  @Test func testClientIdSavedToKeychainOnClientDidSet() throws {
    let clientIdInKeychain = LockIsolated<String?>(nil)
    
    let clerk = withDependencies {
      $0.clerkClient.saveClientIdToKeychain = { @Sendable clientId in
        clientIdInKeychain.setValue(clientId)
      }
    } operation: {
      Clerk()
    }
    
    clerk.client = .mock
    
    #expect(clientIdInKeychain.value == Client.mock.id)
  }
  
  @MainActor
  @Test func testUserShortcut() async throws {
    #expect(clerk.user == nil)
    
    clerk.client = Client.mock
    #expect(clerk.user?.id == User.mock.id)
  }
  
  @MainActor
  @Test func testSessionShortcut() async throws {
    #expect(clerk.session == nil)
    
    clerk.client = Client.mock
    #expect(clerk.session?.id == Session.mock.id)
  }
  
  @MainActor
  @Test func testConfigureWithInvalidKey() async throws {
    clerk.configure(publishableKey: "     ")
    #expect(clerk.publishableKey == "")
  }
  
  @MainActor
  @Test func testLoadWithInvalidKey() async throws {
    clerk.configure(publishableKey: "     ")
    
    await #expect(throws: Error.self) {
      try await clerk.load()
    }
  }
    
  @Test func testSignOutRequest() async throws {
    let clerk = withDependencies {
      $0.clerkClient = .liveValue
    } operation: {
      Clerk()
    }
    
    let originalUrl = APIClient.mockBaseUrl.appending(path: "/v1/client/sessions")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Client>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url!.path() == "/v1/client/sessions")
    }
    mock.register()
    try await clerk.signOut()
  }
  
  @Test func testSignOutWithSessionIdRequest() async throws {
    let clerk = withDependencies {
      $0.clerkClient = .liveValue
    } operation: {
      Clerk()
    }
    
    let originalUrl = APIClient.mockBaseUrl.appending(path: "/v1/client/sessions/\(Session.mock.id)/remove")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Session>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.path() == "/v1/client/sessions/\(Session.mock.id)/remove")
    }
    mock.register()
    try await clerk.signOut(sessionId: Session.mock.id)
  }
  
  @Test func testSetActiveRequest() async throws {
    let clerk = withDependencies {
      $0.clerkClient = .liveValue
    } operation: {
      Clerk()
    }
    
    let originalUrl = APIClient.mockBaseUrl.appending(path: "/v1/client/sessions/\(Session.mock.id)/touch")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Session>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.path() == "/v1/client/sessions/\(Session.mock.id)/touch")
    }
    mock.register()
    try await clerk.setActive(sessionId: Session.mock.id)
  }
  
  
}
