@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkInvalidAuthResponseMiddlewareTests {
  @Test
  func cancelledRefreshCannotReleaseItsReplacement() async throws {
    let service = SuspendedInvalidAuthClientService()
    defer { service.cancelAll() }
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope), clientService: service)
    let old = clerk.startRefreshClientAfterInvalidAuth()
    try await service.waitForRequests(1)
    clerk.cleanupManagers()
    let replacement = clerk.startRefreshClientAfterInvalidAuth()
    try await service.waitForRequests(2)
    #expect(old.isCancelled)
    service.complete(0)
    await old.value
    let coalesced = clerk.startRefreshClientAfterInvalidAuth()
    #expect(coalesced == replacement)
    if coalesced != replacement { try await service.waitForRequests(3) }
    #expect(service.calls == 2)
    service.cancelAll()
    await replacement.value
    await coalesced.value
    // Finishing the current owner still releases the slot for the next recovery.
    let later = clerk.startRefreshClientAfterInvalidAuth()
    try await service.waitForRequests(service.calls + 1)
    #expect(later != replacement)
    service.cancelAll()
    await later.value
  }

  @Test
  func coalescesConcurrentInvalidAuthRefreshes() async {
    let refreshCount = LockIsolated(0)
    let clerk = Clerk()

    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      clientService: MockClientService(get: {
        refreshCount.withValue { $0 += 1 }
        try await Task.sleep(for: .milliseconds(100))
        return Client.mock
      })
    )

    async let first: Void = clerk.refreshClientAfterInvalidAuth()
    async let second: Void = clerk.refreshClientAfterInvalidAuth()
    _ = await (first, second)

    #expect(refreshCount.withValue { $0 } == 1)
  }
}

@MainActor
final class SuspendedInvalidAuthClientService: ClientServiceProtocol {
  private(set) var calls = 0
  private var requests: [Int: CheckedContinuation<ClientServiceResponse, any Error>] = [:]

  func getResponse(skipClientId _: Bool = false) async throws -> ClientServiceResponse {
    let index = calls
    calls += 1
    // Deliberately defer cancellation completion, as a transport may do.
    return try await withCheckedThrowingContinuation { requests[index] = $0 }
  }

  func waitForRequests(_ count: Int) async throws {
    let deadline = ContinuousClock.now + .seconds(1)
    while calls < count, ContinuousClock.now < deadline {
      await Task.yield()
    }
    try #require(calls >= count)
  }

  func complete(_ index: Int) {
    requests.removeValue(forKey: index)?.resume(returning: ClientServiceResponse(client: .mock, requestSequence: nil, serverDate: nil))
  }

  func cancelAll() {
    let pending = requests.values
    requests.removeAll()
    pending.forEach { $0.resume(throwing: CancellationError()) }
  }
}
