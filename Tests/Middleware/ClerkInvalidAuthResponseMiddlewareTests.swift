@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkInvalidAuthResponseMiddlewareTests {
  @Test
  func coalescesConcurrentInvalidAuthRefreshes() async {
    let refreshCount = LockIsolated(0)
    let clerk = Clerk()

    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: MockClientService(get: {
        refreshCount.setValue(refreshCount.value + 1)
        try await Task.sleep(for: .milliseconds(100))
        return Client.mock
      })
    )

    async let first: Void = clerk.refreshClientAfterInvalidAuth()
    async let second: Void = clerk.refreshClientAfterInvalidAuth()
    _ = await (first, second)

    #expect(refreshCount.value == 1)
  }
}
