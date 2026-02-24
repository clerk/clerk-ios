//
//  ClientService.swift
//  Clerk
//

import Foundation

protocol ClientServiceProtocol: Sendable {
  @MainActor func get() async throws -> Client?
  @MainActor func prepareAuthenticatedWebURL(for destinationURL: URL) async throws -> URL
}

final class ClientService: ClientServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func get() async throws -> Client? {
    let request = Request<ClientResponse<Client?>>(path: "/v1/client")
    return try await apiClient.send(request).value.response
  }

  @MainActor
  func prepareAuthenticatedWebURL(for destinationURL: URL) async throws -> URL {
    let request = Request<ClientResponse<PrepareWebviewResource>>(
      path: "/v1/client/prepare_webview",
      method: .post,
      body: [
        "redirect_url": destinationURL.absoluteString,
      ]
    )

    let response = try await apiClient.send(request).value.response
    guard
      let authenticatedURL = URL(string: response.redirectUrl),
      authenticatedURL.scheme?.isEmpty == false
    else {
      throw ClerkClientError(message: "Authenticated web URL is invalid.")
    }

    return authenticatedURL
  }
}

private struct PrepareWebviewResource: Codable, Sendable {
  let redirectUrl: String
}
