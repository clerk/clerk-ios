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

  @Test
  func invalidAuthRefreshSuppressesDeviceTokenPersistenceWhileClearIsPending() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue)
    let clientService = CapturingClientService()

    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      clientService: clientService
    )

    await clerk.refreshClientAfterInvalidAuth()

    #expect(clientService.skipClientIdValues == [true])
    #expect(clientService.suppressDeviceTokenPersistenceValues == [true])
  }

  @Test
  func refreshClientSuppressesDeviceTokenPersistenceWhileClearIsPending() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue)
    let clientService = CapturingClientService()

    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      clientService: clientService
    )

    try await clerk.refreshClient()

    #expect(clientService.skipClientIdValues == [false])
    #expect(clientService.suppressDeviceTokenPersistenceValues == [true])
  }

  @Test
  func refreshClientDoesNotSuppressDeviceTokenPersistenceWhenStaleClearPendingHasStoredToken() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("current-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue)
    let clientService = CapturingClientService()

    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      clientService: clientService
    )

    try await clerk.refreshClient()

    #expect(clientService.skipClientIdValues == [false])
    #expect(clientService.suppressDeviceTokenPersistenceValues == [false])
  }
}

private final class CapturingClientService: ClientServiceProtocol {
  private let skipClientIdValuesStore = LockIsolated([Bool]())
  private let suppressDeviceTokenPersistenceValuesStore = LockIsolated([Bool]())

  var skipClientIdValues: [Bool] {
    skipClientIdValuesStore.value
  }

  var suppressDeviceTokenPersistenceValues: [Bool] {
    suppressDeviceTokenPersistenceValuesStore.value
  }

  @MainActor
  func getResponse(skipClientId: Bool, suppressDeviceTokenPersistence: Bool) async throws -> ClientServiceResponse {
    skipClientIdValuesStore.withValue { $0.append(skipClientId) }
    suppressDeviceTokenPersistenceValuesStore.withValue { $0.append(suppressDeviceTokenPersistence) }
    return ClientServiceResponse(client: nil, requestSequence: 1, serverDate: nil)
  }
}
