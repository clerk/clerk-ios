@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct ClerkInvalidAuthResponseMiddlewareTests {
  @Test
  func coalescesConcurrentInvalidAuthRefreshes() async throws {
    let refreshCount = LockIsolated(0)
    let gate = RefreshGate()
    let clerk = Clerk()

    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: MockClientService(get: {
        refreshCount.withValue { $0 += 1 }
        await gate.signalStarted()
        await gate.waitForRelease()
        return Client.mock
      })
    )
    let middleware = ClerkInvalidAuthResponseMiddleware(
      refreshClientAfterInvalidAuth: {
        await clerk.refreshClientAfterInvalidAuth()
      }
    )
    let request = try URLRequest(url: #require(URL(string: "https://example.com/v1/me")))
    let response = try #require(HTTPURLResponse(
      url: #require(URL(string: "https://example.com/v1/me")),
      statusCode: 401,
      httpVersion: nil,
      headerFields: nil
    ))
    let data = """
    {"errors":[{"message":"invalid auth","long_message":"invalid auth","code":"authentication_invalid"}]}
    """.data(using: .utf8)!

    async let first: Void = middleware.validate(response, data: data, for: request)
    async let second: Void = middleware.validate(response, data: data, for: request)
    await gate.waitUntilStarted()
    await Task.yield()
    await gate.release()
    _ = try await (first, second)

    #expect(refreshCount.withValue { $0 } == 1)
  }
}

private actor RefreshGate {
  private var started = false
  private var released = false
  private var startedContinuation: CheckedContinuation<Void, Never>?
  private var releaseContinuation: CheckedContinuation<Void, Never>?

  func signalStarted() {
    started = true
    startedContinuation?.resume()
    startedContinuation = nil
  }

  func waitUntilStarted() async {
    guard !started else { return }
    await withCheckedContinuation { continuation in
      startedContinuation = continuation
    }
  }

  func waitForRelease() async {
    guard !released else { return }
    await withCheckedContinuation { continuation in
      releaseContinuation = continuation
    }
  }

  func release() {
    released = true
    releaseContinuation?.resume()
    releaseContinuation = nil
  }
}
