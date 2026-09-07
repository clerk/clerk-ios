@testable import ClerkKit
import ClerkSnapshots
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkInvalidAuthResponseMiddlewareTests {
  @Test
  func coalescesConcurrentInvalidAuthRefreshes() async {
    configureClerkForTesting()
    let clerk = Clerk()
    let engine = DelayedRefreshEngine()
    Clerk.engineClient = engine
    defer { Clerk.engineClient = nil }
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope)
    )

    async let first: Void = clerk.refreshClientAfterInvalidAuth()
    async let second: Void = clerk.refreshClientAfterInvalidAuth()
    _ = await (first, second)

    #expect(engine.refreshCount == 1)
  }
}

@MainActor
private final class DelayedRefreshEngine: ClerkEngineClient {
  private(set) var refreshCount = 0

  func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue {
    if invocation.method == "refreshClient" {
      refreshCount += 1
      try await Task.sleep(for: .milliseconds(100))
    }
    return .null
  }
}
