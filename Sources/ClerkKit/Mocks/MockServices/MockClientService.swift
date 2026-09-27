//
//  MockClientService.swift
//  Clerk
//

import Foundation

/// Supplies synthetic HTTP responses to the real Clerk middleware for tests and previews.
package final class MockClientService: ClientServiceProtocol {
  struct Response {
    var client: Client?
    var serverDate: Date? = Date()
  }

  package nonisolated(unsafe) var getHandler: (@MainActor () async throws -> Client?)?
  nonisolated(unsafe) var responseHandler: (@MainActor (URLRequest) async throws -> Response)?
  private nonisolated(unsafe) var apiClient: APIClient?

  package init(get: (@MainActor () async throws -> Client?)? = nil) {
    getHandler = get
  }

  func bind(to apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  package func get(skipClientId: Bool = false) async throws -> Client? {
    guard let apiClient else {
      throw ClerkClientError(message: "Install MockClientService in a mock dependency container before using it.", localizationBundle: .module)
    }
    let runtime = apiClient.runtimeScope
    let pipeline = NetworkingPipeline.clerkDefault(runtimeScope: runtime)
    try Task.checkCancellation()
    try runtime.validateStableRuntime()
    let url = URL(string: "https://mock.clerk.accounts.dev/v1/client")!
    var request = URLRequest(url: url)
    await request.setClerkRequestSequence(apiClient.makeRequestSequence())
    request.setValue("1", forHTTPHeaderField: ClerkHeaderRequestMiddleware.canonicalClientRequestHeader)
    request.setValue(skipClientId ? "1" : "0", forHTTPHeaderField: ClerkHeaderRequestMiddleware.skipClientIdHeader)
    try await pipeline.prepare(&request)

    let response: Response = if let responseHandler {
      try await responseHandler(request)
    } else if let getHandler {
      try await Response(client: getHandler())
    } else {
      Response(client: .mock)
    }
    try Task.checkCancellation()
    try runtime.validateStableRuntime()
    var headers: [String: String] = [:]
    if let date = response.serverDate {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
      headers["Date"] = formatter.string(from: date)
    }
    if response.client != nil, request.clerkRequestDeviceToken == nil {
      headers["Authorization"] = "mock-device-token"
    }
    let httpResponse = HTTPURLResponse(url: request.url ?? url, statusCode: 200, httpVersion: nil, headerFields: headers)!
    let data = try JSONEncoder.clerkEncoder.encode(ClientResponse<Client?>(response: response.client, client: response.client))
    try await pipeline.validate(httpResponse, data: data, for: request)
    try runtime.validateStableRuntime()
    return response.client
  }
}
