import ConcurrencyExtras
import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct EnvironmentTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  @Test
  func refreshEnvironmentUsesService() async throws {
    let called = LockIsolated(false)
    let service = MockEnvironmentService(get: {
      called.setValue(true)
      return .mock
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      environmentService: service
    )

    _ = try await Clerk.shared.refreshEnvironment()

    #expect(called.value == true)
  }
}
