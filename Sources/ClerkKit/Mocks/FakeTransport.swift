//
//  FakeTransport.swift
//  Clerk
//

import Foundation

@MainActor
package final class FakeTransport: APITransport {
  package struct Call {
    package let method: HTTPMethod
    package let path: String
    package let headers: [String: String]
    package let query: [URLQueryItem]
    package let body: JSON?
    package let uploadBody: Data?
    package let isScopedToActiveSession: Bool
  }

  package enum Failure: Error {
    case unstubbed(method: HTTPMethod, path: String)
    case mismatchedResponseType(method: HTTPMethod, path: String)
  }

  private struct Stub {
    let method: HTTPMethod
    let pathPattern: [Substring]
    let respond: @MainActor (Call) async throws -> Any

    func matches(_ call: Call) -> Bool {
      let components = FakeTransport.pathComponents(call.path)
      return method == call.method
        && components.count == pathPattern.count
        && zip(pathPattern, components).allSatisfy { $0 == FakeTransport.anyPathSegment || $0 == $1 }
    }
  }

  package nonisolated static let anyPathSegment = "*"

  private nonisolated static let baseURL = URL(string: "https://fake.clerk.test")!
  private var stubs: [Stub] = []
  package private(set) var calls: [Call] = []

  package init() {}

  package func stub<Value: Decodable & Sendable>(
    _ request: Request<Value>,
    respond: @escaping @MainActor (Call) async throws -> Value
  ) {
    stubs.append(Stub(method: request.method, pathPattern: Self.pathComponents(request.path)) { call in
      try await respond(call) as Any
    })
  }

  package func stub<Value: Decodable & Sendable>(_ request: Request<Value>, returning value: Value) {
    stub(request) { _ in value }
  }

  func send<Value: Decodable & Sendable>(_ request: Request<Value>) async throws -> APIResponse<Value> {
    try await respond(to: request, uploadBody: nil)
  }

  func upload<Value: Decodable & Sendable>(for request: Request<Value>, from body: Data) async throws -> APIResponse<Value> {
    try await respond(to: request, uploadBody: body)
  }

  private func respond<Value: Decodable & Sendable>(
    to request: Request<Value>,
    uploadBody: Data?
  ) async throws -> APIResponse<Value> {
    let urlRequest = try request.makeURLRequest(baseURL: Self.baseURL, encoder: .clerkEncoder)
    let call = try Call(request, urlRequest: urlRequest, uploadBody: uploadBody)
    calls.append(call)
    guard let stub = stubs.last(where: { $0.matches(call) }) else {
      throw Failure.unstubbed(method: call.method, path: call.path)
    }
    guard let value = try await stub.respond(call) as? Value else {
      throw Failure.mismatchedResponseType(method: call.method, path: call.path)
    }
    // Requests that defer client sync hand their caller the metadata the live pipeline would.
    let deferredClientSyncMetadata: ClientSyncResponseMetadata? =
      if !urlRequest.shouldAutomaticallySyncClerkClient,
      let url = urlRequest.url,
      let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) {
        ClientSyncResponseMetadata(response: response, request: urlRequest)
      } else {
        nil
      }
    return APIResponse(
      value: value,
      requestSequence: nil,
      serverDate: nil,
      deferredClientSyncMetadata: deferredClientSyncMetadata
    )
  }

  private nonisolated static func pathComponents(_ path: String) -> [Substring] {
    path.split(separator: "/", omittingEmptySubsequences: true)
  }
}

extension FakeTransport.Call {
  fileprivate init(_ request: Request<some Decodable & Sendable>, urlRequest: URLRequest, uploadBody: Data?) throws {
    guard let url = urlRequest.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw RequestError.invalidURL(path: request.path)
    }
    method = request.method
    path = components.path
    headers = urlRequest.allHTTPHeaderFields ?? [:]
    query = components.queryItems ?? []
    body = try urlRequest.httpBody.map { try JSONDecoder().decode(JSON.self, from: $0) }
    self.uploadBody = uploadBody
    isScopedToActiveSession = urlRequest.isScopedToClerkActiveSession
  }
}
