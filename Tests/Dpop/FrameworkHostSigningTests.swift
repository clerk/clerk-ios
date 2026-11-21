@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct FrameworkHostSigningTests {
  private let url = "https://clerk.example.com/v1/client/sessions/sess_1/tokens?_is_native=true#top"

  init() {
    configureClerkForTesting()
  }

  @Test
  func everyProofBindsItsOwnRequest() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: false, hostSignsRequests: true))

    let first = try await claims(#require(Clerk.shared.deviceBindingProof(method: "POST", url: url, authorization: "token-1")))
    let second = try await claims(#require(Clerk.shared.deviceBindingProof(method: "GET", url: url, authorization: "Bearer token-2")))

    #expect(first["htm"] as? String == "POST")
    #expect(second["htm"] as? String == "GET")
    #expect(first["htu"] as? String == "https://clerk.example.com/v1/client/sessions/sess_1/tokens")
    #expect(first["ath"] as? String == DpopProof.accessTokenHash("token-1"))
    #expect(second["ath"] as? String == DpopProof.accessTokenHash("token-2"))
    #expect(first["jti"] as? String != second["jti"] as? String)
  }

  @Test
  func aRequestWithoutATokenIsSignedWithoutAth() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: false, hostSignsRequests: true))

    let proof = try await claims(#require(Clerk.shared.deviceBindingProof(method: "GET", url: url, authorization: nil)))

    #expect(proof["ath"] == nil)
  }

  @Test
  func aHostThatDidNotOptInGetsNoProof() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: false))

    #expect(try await Clerk.shared.deviceBindingProof(method: "GET", url: url, authorization: boundToken()) == nil)
  }

  @Test
  func aHostThatOptedInSignsItsOwnRequestsThroughTheSdk() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: false, hostSignsRequests: true))
    let middleware = ClerkDpopRequestMiddleware(runtimeScope: Clerk.shared.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: url)))
    request.setValue("expo", forHTTPHeaderField: "x-clerk-host-sdk")

    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "DPoP") != nil)
  }

  @Test
  func aSharedTokenGetsNoProof() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: true, hostSignsRequests: true))

    #expect(try await Clerk.shared.deviceBindingProof(method: "GET", url: url, authorization: boundToken()) == nil)
  }

  @Test
  func aDeviceWithoutAKeyGetsNoProof() async throws {
    useDeviceBinding(.signing(with: UnloadableDeviceKeyStore(), sharesToken: false, hostSignsRequests: true))

    #expect(try await Clerk.shared.deviceBindingProof(method: "GET", url: url, authorization: boundToken()) == nil)
  }

  @Test
  func aBoundTokenWhoseKeyCannotSignThrows() async throws {
    useDeviceBinding(.signing(with: UnsignableDeviceKeyStore(), sharesToken: false, hostSignsRequests: true))

    await #expect(throws: DeviceBindingRequestError.proofUnavailable(.keyError)) {
      try await Clerk.shared.deviceBindingProof(method: "GET", url: url, authorization: boundToken())
    }
  }

  @Test
  func anUnboundTokenWhoseKeyCannotSignGetsNoProof() async throws {
    useDeviceBinding(.signing(with: UnsignableDeviceKeyStore(), sharesToken: false, hostSignsRequests: true))

    #expect(try await Clerk.shared.deviceBindingProof(method: "GET", url: url, authorization: "unbound-token") == nil)
  }

  @Test
  func aRecordedServerDateShiftsIat() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: false, hostSignsRequests: true))
    let serverDate = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 + 3600).rounded(.down))

    Clerk.shared.recordServerDate(HTTPURLResponse.httpDateFormatter.string(from: serverDate))

    let iat = try await claims(#require(Clerk.shared.deviceBindingProof(method: "GET", url: url, authorization: nil)))["iat"] as? Int
    let shift = try TimeInterval(#require(iat)) - serverDate.timeIntervalSince1970
    #expect(shift >= 0 && shift < 5)
  }

  @Test
  func anUnparseableServerDateIsIgnored() async throws {
    useDeviceBinding(.signing(with: InMemoryDeviceKeyStore(), sharesToken: false, hostSignsRequests: true))
    Clerk.shared.identityController.resetServerClock()

    Clerk.shared.recordServerDate("not a date")

    let iat = try await claims(#require(Clerk.shared.deviceBindingProof(method: "GET", url: url, authorization: nil)))["iat"] as? Int
    #expect(try abs(TimeInterval(#require(iat)) - Date.now.timeIntervalSince1970) < 5)
  }

  @Test
  func theOptInDefaultsToOff() {
    #expect(Clerk.Options().hostSignsRequests == false)
  }

  private func useDeviceBinding(_ deviceBinding: DeviceBindingState) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      deviceBinding: deviceBinding,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
  }

  private func claims(_ proof: String) throws -> [String: Any] {
    try dpopClaims(proof: proof)
  }
}
