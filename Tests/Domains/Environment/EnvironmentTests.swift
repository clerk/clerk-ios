@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct EnvironmentTests {
  init() {
    Clerk.configure(publishableKey: testPublishableKey)
  }

  @Test
  func refreshEnvironmentUsesEnvironmentServiceGet() async throws {
    let called = LockIsolated(false)
    let expectedEnvironment = Clerk.Environment.mock
    let service = MockEnvironmentService(get: {
      called.setValue(true)
      return expectedEnvironment
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      environmentService: service
    )

    _ = try await Clerk.shared.refreshEnvironment()

    #expect(called.value == true)
    #expect(Clerk.shared.environment == expectedEnvironment)
  }
}
