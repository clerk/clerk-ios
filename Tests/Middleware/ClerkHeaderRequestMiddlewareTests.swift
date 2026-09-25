//
//  ClerkHeaderRequestMiddlewareTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import Foundation
import Testing

/// Tests for ClerkHeaderRequestMiddleware header injection.
@MainActor
@Suite(.serialized)
struct ClerkHeaderRequestMiddlewareTests {
  init() {
    configureClerkForTesting()
  }

  /// Creates a test setup with a fresh keychain and configured dependencies.
  ///
  /// - Returns: A fresh InMemoryKeychain instance.
  private func createTestKeychain() -> InMemoryKeychain {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    return keychain
  }

  @Test
  func addsDeviceTokenHeaderWhenPresent() async throws {
    _ = createTestKeychain()
    try Clerk.shared.seedIdentity(deviceToken: "test-device-token")

    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == "test-device-token")
  }

  @Test
  func requestsUseTheLoadedTokenWithoutReadingStorage() async throws {
    let clerk = Clerk()
    let keychain = ReadCountingKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(
        runtimeScope: .init(epoch: clerk.configurationEpoch, clerkProvider: { clerk })
      ),
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    try clerk.seedIdentity(deviceToken: "hydrated-token", client: .mock)
    keychain.resetReadCount()
    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: clerk.runtimeScope)

    for _ in 0 ..< 3 {
      var request = try URLRequest(url: #require(URL(string: "https://example.com")))
      try await middleware.prepare(&request)
      #expect(request.value(forHTTPHeaderField: "Authorization") == "hydrated-token")
    }

    #expect(keychain.readCount == 0)
  }

  @Test
  func doesNotAddDeviceTokenHeaderWhenMissing() async throws {
    _ = createTestKeychain()

    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
  }

  @Test
  func addsClientIdHeaderWhenAvailable() async throws {
    // Set a mock client
    Clerk.shared.client = .mock

    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == Client.mock.id)
  }

  @Test
  func tagsRequestWithCurrentClientResponseGeneration() async throws {
    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    #expect(request.clerkClientResponseGeneration == Clerk.shared.clientResponseGeneration)
  }

  @Test
  func storesClientResponseGenerationAsURLProtocolPropertyListValue() async throws {
    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    let property = URLProtocol.property(
      forKey: "com.clerk.client-response-generation",
      in: request
    )

    #expect(property is NSNumber)
    #expect(request.clerkClientResponseGeneration == Clerk.shared.clientResponseGeneration)
  }

  @Test
  func concurrentTokenlessRequestsShareStartupTakeoverGeneration() async throws {
    let clerk = Clerk()
    let startupGate = RequestIdentityOperationGate()
    let startupCancellationObserved = RequestStartSignal()
    var startupClient = Client.mock
    startupClient.id = "startup-refresh-client"
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      clientService: MockClientService(get: {
        await startupGate.suspend()
        #expect(Task.isCancelled)
        await startupCancellationObserved.signal()
        try Task.checkCancellation()
        return startupClient
      })
    )
    try clerk.performConfiguration(dependencies: dependencies)
    defer {
      startupGate.resume()
      clerk.cleanupManagers()
    }
    try await startupGate.waitUntilSuspended()
    let startupGeneration = clerk.clientResponseGeneration
    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: clerk.runtimeScope)
    let signUpURL = try #require(URL(string: "https://example.com/v1/client/sign_ups"))

    func prepareTokenlessRequest() async throws -> URLRequest {
      var request = URLRequest(url: signUpURL)
      request.setClerkStartupClientRefreshTakeoverID(UUID())
      try await middleware.prepare(&request)
      return request
    }

    async let firstRequest = prepareTokenlessRequest()
    async let secondRequest = prepareTokenlessRequest()
    let (first, second) = try await (firstRequest, secondRequest)

    #expect(first.clerkRequestDeviceToken == nil)
    #expect(second.clerkRequestDeviceToken == nil)
    #expect(first.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(second.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(clerk.clientResponseGeneration != startupGeneration)
    #expect(first.clerkClientResponseGeneration == second.clerkClientResponseGeneration)
    #expect(first.clerkClientResponseGeneration == clerk.clientResponseGeneration)
    #expect(second.clerkClientResponseGeneration == clerk.clientResponseGeneration)

    try await clerk.identityController.applyNetworkResponse(
      responseContext(
        clientID: "stale-startup-client",
        generation: startupGeneration
      )
    )
    #expect(clerk.client == nil)

    let acceptedGeneration = try #require(second.clerkClientResponseGeneration)
    try await clerk.identityController.applyNetworkResponse(
      responseContext(
        clientID: "accepted-tokenless-client",
        generation: acceptedGeneration
      )
    )
    #expect(clerk.client?.id == "accepted-tokenless-client")

    startupGate.resume()
    await startupCancellationObserved.wait()
    #expect(clerk.client?.id == "accepted-tokenless-client")
  }

  @Test
  func omitsClientIdHeaderWhenSkipClientIdHeaderIsPresent() async throws {
    Clerk.shared.client = .mock

    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))
    request.setValue("1", forHTTPHeaderField: ClerkHeaderRequestMiddleware.skipClientIdHeader)

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == nil)
    #expect(request.value(forHTTPHeaderField: ClerkHeaderRequestMiddleware.skipClientIdHeader) == nil)
  }

  @Test
  func doesNotAddClientIdHeaderWhenClientMissing() async throws {
    // Ensure no client is set
    Clerk.shared.client = nil

    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == nil)
  }

  @Test
  func addsNativeDeviceIdHeaderWhenAvailable() async throws {
    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    if let deviceId = DeviceHelper.deviceID {
      let headerValue = request.value(forHTTPHeaderField: "x-native-device-id")
      #expect(headerValue != nil, "Should include device ID header when available")
      #expect(headerValue == deviceId)
    } else {
      let headerValue = request.value(forHTTPHeaderField: "x-native-device-id")
      #expect(headerValue == nil, "Should not include device ID header when unavailable")
    }
  }

  @Test
  func addsDeviceTypeHeader() async throws {
    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    let headerValue = request.value(forHTTPHeaderField: "x-device-type")
    #expect(headerValue != nil, "Should always include device type header")
    #expect(["ipad", "iphone", "mac", "carplay", "tv", "vision", "watch", "unspecified"].contains(headerValue ?? ""), "Device type should be one of the expected values")
  }

  @Test
  func addsDeviceInfoHeaders() async throws {
    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "x-device-model") != nil, "Should include device model header")
    #expect(request.value(forHTTPHeaderField: "x-os-version") != nil, "Should include OS version header")
    #expect(request.value(forHTTPHeaderField: "x-app-version") != nil, "Should include app version header")
    #expect(request.value(forHTTPHeaderField: "x-bundle-id") != nil, "Should include bundle ID header")
    #expect(request.value(forHTTPHeaderField: "x-is-sandbox") != nil, "Should include sandbox header")
    #expect(["true", "false"].contains(request.value(forHTTPHeaderField: "x-is-sandbox") ?? ""), "Sandbox should be true or false")
  }

  private func responseContext(
    clientID: String,
    generation: ClientResponseGeneration
  ) -> ClientSyncResponseContext {
    var client = Client.mockSignedOut
    client.id = clientID
    return ClientSyncResponseContext(
      update: .client(client),
      deviceTokenUpdate: .set("response-token"),
      requestDeviceToken: nil,
      serverDate: nil,
      isCanonicalClientRequest: true,
      clientResponseGeneration: generation,
      responseSequence: nil
    )
  }
}

@MainActor
private final class RequestIdentityOperationGate {
  private(set) var isSuspended = false
  private var continuation: CheckedContinuation<Void, Never>?

  func suspend() async {
    isSuspended = true
    await withCheckedContinuation { continuation = $0 }
    isSuspended = false
  }

  func waitUntilSuspended() async throws {
    let deadline = ContinuousClock.now + .seconds(1)
    while ContinuousClock.now < deadline {
      if isSuspended { return }
      await Task.yield()
    }
    throw ClerkClientError(message: "Timed out waiting for local identity operation.")
  }

  func resume() {
    continuation?.resume()
    continuation = nil
  }
}

private actor RequestStartSignal {
  private var didStart = false
  private var continuations: [CheckedContinuation<Void, Never>] = []

  func signal() {
    didStart = true
    continuations.forEach { $0.resume() }
    continuations.removeAll()
  }

  func wait() async {
    guard !didStart else { return }
    await withCheckedContinuation { continuation in
      continuations.append(continuation)
    }
  }
}

private final class ReadCountingKeychain: @unchecked Sendable, KeychainStorage {
  private let backing = InMemoryKeychain()
  private let lock = NSLock()
  private var reads = 0

  var readCount: Int {
    lock.withLock { reads }
  }

  func resetReadCount() {
    lock.withLock { reads = 0 }
  }

  func set(_ data: Data, forKey key: String) throws {
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    lock.withLock { reads += 1 }
    return try backing.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.withLock { reads += 1 }
    return try backing.hasItem(forKey: key)
  }
}
