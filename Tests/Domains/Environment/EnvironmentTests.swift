@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.unit))
struct EnvironmentTests {
  @Test
  func refreshEnvironmentUsesEnvironmentServiceGet() async throws {
    let called = LockIsolated(false)
    let expectedEnvironment = Clerk.Environment.mock
    let service = MockEnvironmentService(get: {
      called.setValue(true)
      return expectedEnvironment
    })
    let clerk = try ClerkTestFixture().makeClerk(environmentService: service)

    _ = try await clerk.refreshEnvironment()

    #expect(called.value == true)
    #expect(clerk.environment == expectedEnvironment)
  }
}
