@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkDeviceBindingResponseMiddlewareTests {
  private let url = URL(string: "https://clerk.example.com/v1/client")!

  init() {
    configureClerkForTesting()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
    Clerk.shared.identityController.resetRuntimeIdentity()
  }

  @Test(arguments: [DeviceBindingError.proofMissing, .keyMismatch])
  func aTokenBoundElsewhereIsDropped(_ error: DeviceBindingError) async throws {
    let token = try boundToken()
    try Clerk.shared.seedIdentity(deviceToken: token, client: .mock)

    try await middleware().validate(response(401), data: body(error.rawValue), for: request(token: token))

    #expect(Clerk.shared.identityController.currentDeviceToken == nil)
    #expect(Clerk.shared.client == nil)
  }

  @Test
  func aReplayedProofKeepsTheToken() async throws {
    let token = try boundToken()
    try Clerk.shared.seedIdentity(deviceToken: token, client: .mock)

    try await middleware().validate(
      response(401),
      data: body(DeviceBindingError.proofReplayed.rawValue),
      for: request(token: token)
    )

    #expect(Clerk.shared.identityController.currentDeviceToken == token)
  }

  @Test
  func aTokenThatChangedSinceTheRequestIsKept() async throws {
    let newer = try testJWT(claims: ["id": "client_2", "cnf": ["jkt": "thumbprint"]])
    try Clerk.shared.seedIdentity(deviceToken: newer, client: .mock)

    try await middleware().validate(
      response(401),
      data: body(DeviceBindingError.keyMismatch.rawValue),
      for: request(token: boundToken())
    )

    #expect(Clerk.shared.identityController.currentDeviceToken == newer)
  }

  @Test
  func aBindingCodeOnAnotherStatusIsIgnored() async throws {
    let token = try boundToken()
    try Clerk.shared.seedIdentity(deviceToken: token, client: .mock)

    try await middleware().validate(
      response(400),
      data: body(DeviceBindingError.proofMissing.rawValue),
      for: request(token: token)
    )

    #expect(Clerk.shared.identityController.currentDeviceToken == token)
  }

  @Test
  func anInvalidProofIsRetriedOnceOnTheServerClock() async throws {
    let retry = ClerkDpopRetryMiddleware()
    var signed = request(token: "token")
    signed.setValue("proof", forHTTPHeaderField: "DPoP")
    let invalid = ClerkAPIError(code: DeviceBindingError.proofInvalid.rawValue)
    let dated = response(401, headers: ["Date": "Tue, 18 Nov 2026 10:00:00 GMT"])

    #expect(try await retry.shouldRetry(request: signed, response: dated, error: invalid, attempts: 1))
    #expect(try await !retry.shouldRetry(request: signed, response: dated, error: invalid, attempts: 2))
    #expect(try await !retry.shouldRetry(request: request(token: "token"), response: dated, error: invalid, attempts: 1))
    #expect(try await !retry.shouldRetry(request: signed, response: response(401), error: invalid, attempts: 1))
    #expect(try await !retry.shouldRetry(
      request: signed,
      response: dated,
      error: ClerkAPIError(code: DeviceBindingError.proofReplayed.rawValue),
      attempts: 1
    ))
  }

  @Test
  func anAppThatSharesItsTokenDropsABoundTokenAtLaunch() throws {
    try Clerk.shared.seedIdentity(deviceToken: boundToken(), client: .mock)

    Clerk.shared.identityController.dropDeviceBoundToken()

    #expect(Clerk.shared.identityController.currentDeviceToken == nil)
  }

  @Test
  func anAppThatSharesItsTokenKeepsAnUnboundToken() throws {
    try Clerk.shared.seedIdentity(deviceToken: "unbound-token", client: .mock)

    Clerk.shared.identityController.dropDeviceBoundToken()

    #expect(Clerk.shared.identityController.currentDeviceToken == "unbound-token")
  }

  private func middleware() -> ClerkDeviceBindingResponseMiddleware {
    ClerkDeviceBindingResponseMiddleware(runtimeScope: Clerk.shared.runtimeScope)
  }

  private func request(token: String) -> URLRequest {
    var request = URLRequest(url: url)
    request.setValue(token, forHTTPHeaderField: "Authorization")
    return request
  }

  private func response(_ statusCode: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
  }

  private func body(_ code: String) throws -> Data {
    try JSONSerialization.data(withJSONObject: ["errors": [["code": code, "message": code]]])
  }
}
