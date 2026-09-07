import Foundation

protocol SignInServiceProtocol: Sendable {
  @MainActor func create(params: SignIn.CreateParams) async throws -> SignIn
  @MainActor func attemptFirstFactor(signInId: String, params: SignIn.AttemptFirstFactorParams) async throws -> SignIn
}

final class SignInService: SignInServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func create(params: SignIn.CreateParams) async throws -> SignIn {
    let request = Request<ClientResponse<SignIn>>(
      path: "/v1/client/sign_ins",
      method: .post,
      canEstablishClientWhenTokenless: true,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptFirstFactor(signInId: String, params: SignIn.AttemptFirstFactorParams) async throws -> SignIn {
    let request = Request<ClientResponse<SignIn>>(
      path: "/v1/client/sign_ins/\(signInId)/attempt_first_factor",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }
}
