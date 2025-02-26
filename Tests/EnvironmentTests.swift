import Testing
import Foundation
import Mocker

@testable import Clerk
@testable import Factory
@testable import Get

@Suite(.serialized) struct EnvironmentSerializedTests {
  
  init() {
    Container.shared.reset()
  }
  
  @Test func testEnvironmentGet() async throws {
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/environment")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .get: try! JSONEncoder.clerkEncoder.encode(Clerk.Environment())
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url!.path() == "/v1/environment")
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await Clerk.Environment.get()
    #expect(requestHandled.value)
  }
  
}
