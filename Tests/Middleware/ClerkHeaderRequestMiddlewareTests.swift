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
    let keychain = createTestKeychain()
    try keychain.set("test-device-token", forKey: "clerkDeviceToken")

    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == "test-device-token")
  }

  @Test
  func adoptedIdentityUsesHydratedTokenWithoutReadingStoragePerRequest() async throws {
    let clerk = Clerk()
    let identity = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "hydrated-token",
      client: .mock,
      serverDate: nil
    )
    let store = ReadCountingIdentityStore(identity: identity)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(
        runtimeScope: .init(epoch: clerk.configurationEpoch, clerkProvider: { clerk })
      ),
      sharedSessionLocalIdentityStore: store,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.setSharedSessionIdentityIfNeeded(identity)
    store.resetReadCount()
    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: clerk.runtimeScope)

    for _ in 0 ..< 3 {
      var request = try URLRequest(url: #require(URL(string: "https://example.com")))
      try await middleware.prepare(&request)
      #expect(request.value(forHTTPHeaderField: "Authorization") == "hydrated-token")
    }

    #expect(store.readCount == 0)
  }

  @Test
  func appLocalRequestSnapshotWaitsBehindQueuedIdentityTransition() async throws {
    let clerk = Clerk()
    let store = ReadCountingIdentityStore(identity: SharedSessionLocalIdentity(
      state: .cleared,
      deviceToken: nil,
      client: nil,
      serverDate: nil
    ))
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(
        runtimeScope: .init(epoch: clerk.configurationEpoch, clerkProvider: { clerk })
      ),
      sharedSessionLocalIdentityStore: store,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let localIdentityIO = try #require(clerk.dependencies.sharedSessionLocalIdentityIO)
    let gate = RequestIdentityOperationGate()
    let identity = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "queued-token",
      client: .mock,
      serverDate: nil
    )
    let transition = clerk.enqueueLocalIdentityOperation { operationRevision in
      await gate.suspend()
      return try await clerk.persistAndApplyAtomicLocalIdentity(
        identity,
        through: localIdentityIO,
        operationRevision: operationRevision,
        fenceAllClientResponses: false
      )
    }
    try await gate.waitUntilSuspended()

    var didPrepare = false
    let requestTask = Task { @MainActor in
      var request = try URLRequest(url: #require(URL(string: "https://example.com")))
      try await ClerkHeaderRequestMiddleware(runtimeScope: clerk.runtimeScope)
        .prepare(&request)
      didPrepare = true
      return request
    }
    await Task.yield()
    #expect(!didPrepare)

    gate.resume()
    #expect(try await transition.value)
    let request = try await requestTask.value
    #expect(request.value(forHTTPHeaderField: "Authorization") == "queued-token")
    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == Client.mock.id)
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

private final class ReadCountingIdentityStore: @unchecked Sendable, SharedSessionLocalIdentityStoring {
  private let lock = NSLock()
  private var record: SharedSessionLocalIdentityRecord?
  private var reads = 0

  init(identity: SharedSessionLocalIdentity) {
    record = SharedSessionLocalIdentityRecord(
      acceptedIdentity: identity,
      pendingPublication: nil
    )
  }

  var readCount: Int {
    lock.withLock { reads }
  }

  func resetReadCount() {
    lock.withLock { reads = 0 }
  }

  func loadRecord() throws -> SharedSessionLocalIdentityRecord? {
    lock.withLock {
      reads += 1
      return record
    }
  }

  func updateRecord(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws {
    try lock.withLock {
      record = try update(record)
    }
  }
}
