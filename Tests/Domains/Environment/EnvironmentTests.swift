@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct EnvironmentTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func refreshEnvironmentUsesEnvironmentServiceGet() async throws {
    let called = LockIsolated(false)
    let expectedEnvironment = Clerk.Environment.mock
    let service = MockEnvironmentService(get: {
      called.setValue(true)
      return expectedEnvironment
    })
    let clerk = makeClerk(environmentService: service)

    _ = try await clerk.refreshEnvironment()

    #expect(called.value == true)
    #expect(clerk.environment == expectedEnvironment)
  }

  @Test
  func refreshEnvironmentCoalescesConcurrentRequests() async throws {
    let callCount = LockIsolated(0)
    let service = MockEnvironmentService(get: {
      callCount.withValue { $0 += 1 }
      try await Task.sleep(for: .milliseconds(100))
      return .mock
    })
    let clerk = makeClerk(environmentService: service)

    let firstRefresh = Task { @MainActor in
      try await clerk.refreshEnvironment()
    }
    try await waitUntil { callCount.value == 1 }

    let secondRefresh = Task { @MainActor in
      try await clerk.refreshEnvironment()
    }

    _ = try await firstRefresh.value
    _ = try await secondRefresh.value

    #expect(callCount.value == 1)
  }

  @Test
  func ensureEnvironmentRefreshedAfterSatisfiedCheckpointDoesNotRequestAgain() async throws {
    let callCount = LockIsolated(0)
    let service = MockEnvironmentService(get: {
      callCount.withValue { $0 += 1 }
      return .mock
    })
    let clerk = makeClerk(environmentService: service)

    let checkpoint = clerk.environmentRefreshCheckpoint
    _ = try await clerk.refreshEnvironment()
    _ = try await clerk.ensureEnvironmentRefreshed(after: checkpoint)

    #expect(callCount.value == 1)
  }

  @Test
  func ensureEnvironmentRefreshedAfterUnsatisfiedCheckpointRequestsEnvironment() async throws {
    let callCount = LockIsolated(0)
    let service = MockEnvironmentService(get: {
      callCount.withValue { $0 += 1 }
      return .mock
    })
    let clerk = makeClerk(environmentService: service)

    let checkpoint = clerk.environmentRefreshCheckpoint
    _ = try await clerk.ensureEnvironmentRefreshed(after: checkpoint)

    #expect(callCount.value == 1)
  }

  private func makeClerk(environmentService: MockEnvironmentService) -> Clerk {
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      environmentService: environmentService
    )
    return clerk
  }

  private func waitUntil(
    timeout: Duration = .milliseconds(500),
    _ condition: () -> Bool
  ) async throws {
    enum TimeoutError: Error {
      case timedOut
    }

    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if condition() {
        return
      }
      try await Task.sleep(for: .milliseconds(10))
    }

    if !condition() {
      throw TimeoutError.timedOut
    }
  }
}
