@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct SignInServiceSecondFactorTests {
  struct PrepareSecondFactorScenario {
    let strategy: FactorStrategy
    let encodedStrategy: String
  }

  private func makeService(baseURL: URL) -> SignInService {
    SignInService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test(
    arguments: [
      PrepareSecondFactorScenario(strategy: .phoneCode, encodedStrategy: "phone_code"),
      PrepareSecondFactorScenario(strategy: .totp, encodedStrategy: "totp"),
      PrepareSecondFactorScenario(strategy: .backupCode, encodedStrategy: "backup_code"),
    ]
  )
  func prepareSecondFactor(scenario: PrepareSecondFactorScenario) async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)/prepare_second_factor")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      let body = try #require(request.urlEncodedFormBody)
      #expect(body["strategy"] == scenario.encodedStrategy)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).prepareSecondFactor(
      signInId: signIn.id,
      params: .init(strategy: scenario.strategy)
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptSecondFactorPhoneCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)/attempt_second_factor")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptSecondFactor(
      signInId: signIn.id,
      params: .init(strategy: .phoneCode, code: "123456")
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptSecondFactorTotp() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)/attempt_second_factor")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "totp")
      #expect(request.urlEncodedFormBody!["code"] == "654321")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptSecondFactor(
      signInId: signIn.id,
      params: .init(strategy: .totp, code: "654321")
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptSecondFactorBackupCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)/attempt_second_factor")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "backup_code")
      #expect(request.urlEncodedFormBody!["code"] == "backup123")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptSecondFactor(
      signInId: signIn.id,
      params: .init(strategy: .backupCode, code: "backup123")
    )
    #expect(requestHandled.value)
  }
}
