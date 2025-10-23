import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct ClerkProxyRequestMiddlewareTests {
  private let middleware = ClerkProxyRequestMiddleware()

  @Test
  @MainActor
  func testPrepareAddsProxyPath() async throws {
    let originalSettings = Clerk.shared.settings
    defer { Clerk.shared.settings = originalSettings }

    Clerk.shared.settings = .init(proxyUrl: "https://proxy.example/__clerk")

    var request = URLRequest(url: URL(string: "https://proxy.example/v1/client")!)
    try await middleware.prepare(&request)

    #expect(request.url?.absoluteString == "https://proxy.example/__clerk/v1/client")
  }

  @Test
  @MainActor
  func testPrepareNoopForPrefixedPath() async throws {
    let originalSettings = Clerk.shared.settings
    defer { Clerk.shared.settings = originalSettings }

    Clerk.shared.settings = .init(proxyUrl: "https://proxy.example/__clerk")

    let originalUrl = URL(string: "https://proxy.example/__clerk/v1/client")!
    var request = URLRequest(url: originalUrl)
    try await middleware.prepare(&request)

    #expect(request.url == originalUrl)
  }

  @Test
  @MainActor
  func testPrepareNoopWithoutProxy() async throws {
    let originalSettings = Clerk.shared.settings
    defer { Clerk.shared.settings = originalSettings }

    Clerk.shared.settings = .init()

    let originalUrl = URL(string: "https://frontend.example/v1/client")!
    var request = URLRequest(url: originalUrl)
    try await middleware.prepare(&request)

    #expect(request.url == originalUrl)
  }
}
