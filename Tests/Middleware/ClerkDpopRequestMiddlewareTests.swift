@testable import ClerkKit
import ConcurrencyExtras
import CryptoKit
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct ClerkDpopRequestMiddlewareTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func signsTheRequestAsItIsSent() async throws {
    let store = InMemoryDeviceKeyStore()
    useDeviceBinding(.signing(with: store, sharesToken: false))
    let middleware = ClerkDpopRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope, makeJTI: { "jti-1" })
    var request = try URLRequest(url: #require(URL(string: "https://clerk.example.com/v1/client/sign_ins?_is_native=true")))
    request.httpMethod = "POST"
    request.setValue("client-token", forHTTPHeaderField: "Authorization")

    try await middleware.prepare(&request)

    let claims = try dpopClaims(request)
    #expect(claims["htm"] as? String == "POST")
    #expect(claims["htu"] as? String == "https://clerk.example.com/v1/client/sign_ins")
    #expect(claims["ath"] as? String == DpopProof.accessTokenHash("client-token"))
    #expect(claims["jti"] as? String == "jti-1")
    #expect(claims["clerk_sl"] as? String == "software")
  }

  @Test
  func signsARequestThatHasNoTokenYet() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: false))
    let middleware = ClerkDpopRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://clerk.example.com/v1/environment")))

    try await middleware.prepare(&request)

    #expect(try dpopClaims(request)["ath"] == nil)
  }

  @Test
  func eachSignedRequestHasItsOwnJti() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: false))
    let middleware = ClerkDpopRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var first = try URLRequest(url: #require(URL(string: "https://clerk.example.com/v1/client")))
    var second = first

    try await middleware.prepare(&first)
    try await middleware.prepare(&second)

    #expect(try dpopClaims(first)["jti"] as? String != dpopClaims(second)["jti"] as? String)
  }

  @Test
  func aSharedTokenIsSentUnsigned() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: true))
    let middleware = ClerkDpopRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://clerk.example.com/v1/client")))
    try request.setValue(boundToken(), forHTTPHeaderField: "Authorization")

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "DPoP") == nil)
  }

  @Test
  func aFrameworkHostsFirstRequestIsSentUnsignedSoItsClientStaysUnbound() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: false))
    let middleware = ClerkDpopRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://clerk.example.com/v1/client/sign_ins")))
    request.httpMethod = "POST"
    request.setValue("expo", forHTTPHeaderField: "x-clerk-host-sdk")

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "DPoP") == nil)
  }

  @Test
  func aFrameworkHostSendsABoundTokenUnsigned() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: false))
    let middleware = ClerkDpopRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://clerk.example.com/v1/client")))
    try request.setValue(boundToken(), forHTTPHeaderField: "Authorization")
    request.setValue("expo", forHTTPHeaderField: "x-clerk-host-sdk")

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "DPoP") == nil)
  }

  @Test
  func aHostMiddlewareThatNamesItsSdkKeepsEveryRequestUnsigned() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: false))
    let proofs = LockIsolated<[String?]>([])
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/environment")!
    var mock = try Mock(
      url: testURL,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [.get: JSONEncoder().encode(["success": true])]
    )
    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      proofs.withValue { $0.append(request.value(forHTTPHeaderField: "DPoP")) }
    }
    mock.register()
    let runtimeScope = Clerk.shared.runtimeScope
    let apiClient = APIClient(baseURL: mockBaseUrl, runtimeScope: runtimeScope) { configuration in
      configuration.pipeline = NetworkingPipeline(
        proofMiddleware: [ClerkDpopRequestMiddleware(runtimeScope: runtimeScope)]
      ).appendingRequestMiddleware([HostSdkHeaderMiddleware()])
      configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
    }

    _ = try await apiClient.send(Request<EmptyResponse>(path: "/v1/environment"))

    #expect(proofs.value == [nil])
  }

  @Test
  func aRuntimeWithoutAKeySendsUnsigned() async throws {
    useDeviceBinding(.signing(with: UnloadableDeviceKeyStore(), sharesToken: false))
    let middleware = ClerkDpopRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://clerk.example.com/v1/client")))
    try request.setValue(boundToken(), forHTTPHeaderField: "Authorization")

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "DPoP") == nil)
  }

  @Test
  func aSigningErrorFailsADeviceBoundRequest() async throws {
    useDeviceBinding(.signing(with: UnsignableDeviceKeyStore(), sharesToken: false))
    let middleware = ClerkDpopRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://clerk.example.com/v1/client")))
    try request.setValue(boundToken(), forHTTPHeaderField: "Authorization")

    await #expect(throws: DeviceBindingRequestError.proofUnavailable(.keyError)) {
      try await middleware.prepare(&request)
    }
  }

  @Test
  func aSigningErrorSendsAnUnboundRequestUnsigned() async throws {
    useDeviceBinding(.signing(with: UnsignableDeviceKeyStore(), sharesToken: false))
    let middleware = ClerkDpopRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://clerk.example.com/v1/client")))
    request.setValue("unbound-token", forHTTPHeaderField: "Authorization")

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "DPoP") == nil)
  }

  @Test
  func everyAttemptOfARetriedRequestCarriesANewProof() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: false))
    let proofs = LockIsolated<[String]>([])
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/client")!
    var mock = try Mock(
      url: testURL,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [.get: JSONEncoder().encode(["success": true])]
    )
    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      proofs.withValue { $0.append(request.value(forHTTPHeaderField: "DPoP") ?? "") }
    }
    mock.register()
    let runtimeScope = Clerk.shared.runtimeScope
    let apiClient = APIClient(baseURL: mockBaseUrl, runtimeScope: runtimeScope) { configuration in
      configuration.pipeline = NetworkingPipeline(
        proofMiddleware: [ClerkDpopRequestMiddleware(runtimeScope: runtimeScope)],
        responseMiddleware: [FailsFirstResponseMiddleware()],
        retryMiddleware: [RetriesFirstAttemptMiddleware()]
      )
      configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
    }

    _ = try await apiClient.send(Request<EmptyResponse>(path: "/v1/client"))

    #expect(proofs.value.count == 2)
    let jtis = try proofs.value.map { try dpopClaims(proof: $0)["jti"] as? String }
    #expect(Set(jtis).count == 2)
    #expect(try proofs.value.allSatisfy { try dpopClaims(proof: $0)["htu"] as? String == testURL.absoluteString })
  }

  private func useDeviceBinding(_ deviceBinding: DeviceBindingState) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      deviceBinding: deviceBinding,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
  }
}

func boundToken() throws -> String {
  try testJWT(claims: ["id": "client_1", "cnf": ["jkt": "thumbprint"]])
}

func dpopClaims(_ request: URLRequest) throws -> [String: Any] {
  try dpopClaims(proof: #require(request.value(forHTTPHeaderField: "DPoP")))
}

func dpopClaims(proof: String) throws -> [String: Any] {
  let segments = proof.split(separator: ".")
  try #require(segments.count == 3)
  let data = try #require(String(segments[1]).dataFromBase64URL())
  return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

struct UnsignableDeviceKeyStore: DeviceKeyStore {
  private let store = InMemoryDeviceKeyStore()

  func loadOrCreate() throws -> any DeviceKey {
    try UnsignableDeviceKey(base: store.loadOrCreate())
  }

  func hasStoredKey() throws -> Bool {
    try store.hasStoredKey()
  }

  func delete() throws {
    try store.delete()
  }
}

struct UnsignableDeviceKey: DeviceKey {
  let base: any DeviceKey

  var publicJwk: Es256PublicJwk {
    base.publicJwk
  }

  var securityLevel: DeviceKeySecurityLevel {
    base.securityLevel
  }

  func sign(_: Data) throws -> Data {
    throw DeviceKeyError.keychain(errSecInteractionNotAllowed)
  }
}

private struct HostSdkHeaderMiddleware: ClerkRequestMiddleware {
  func prepare(_ request: inout URLRequest) async throws {
    request.addValue("expo", forHTTPHeaderField: "x-clerk-host-sdk")
  }
}

private struct FailsFirstResponseMiddleware: ClerkResponseMiddleware {
  struct Failure: Error {}

  private let calls = LockIsolated(0)

  func validate(_: HTTPURLResponse, data _: Data, for _: URLRequest) async throws {
    let call = calls.withValue { calls in
      calls += 1
      return calls
    }
    if call == 1 {
      throw Failure()
    }
  }
}

private struct RetriesFirstAttemptMiddleware: NetworkRetryMiddleware {
  func shouldRetry(
    request _: URLRequest,
    response _: HTTPURLResponse?,
    error _: any Error,
    attempts: Int
  ) async throws -> Bool {
    attempts == 1
  }
}
