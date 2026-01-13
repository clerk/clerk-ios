import ConcurrencyExtras
import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct ClientTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  @Test
  func refreshClientUsesService() async throws {
    let called = LockIsolated(false)
    let service = MockClientService(get: {
      called.setValue(true)
      return .mock
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      clientService: service
    )

    _ = try await Clerk.shared.refreshClient()

    #expect(called.value == true)
  }
}
