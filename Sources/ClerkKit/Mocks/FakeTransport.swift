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
    package let query: [URLQueryItem]
    package let body: JSON?
    package let isScopedToActiveSession: Bool
  }

  package enum Failure: Error {
    case unstubbed(method: HTTPMethod, path: String)
    case mismatchedResponseType(method: HTTPMethod, path: String)
  }

  private struct Stub {
    let method: HTTPMethod
    let pathPattern: [Substring]
    let respond: @MainActor (Call) throws -> Any

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
    respond: @escaping @MainActor (Call) throws -> Value
  ) {
    stubs.append(Stub(method: request.method, pathPattern: Self.pathComponents(request.path)) { call in
      try respond(call) as Any
    })
  }

  package func stub<Value: Decodable & Sendable>(_ request: Request<Value>, returning value: Value) {
    stub(request) { _ in value }
  }

  func send<Value: Decodable & Sendable>(_ request: Request<Value>) async throws -> APIResponse<Value> {
    let call = try Call(request)
    calls.append(call)
    guard let stub = stubs.last(where: { $0.matches(call) }) else {
      throw Failure.unstubbed(method: call.method, path: call.path)
    }
    guard let value = try stub.respond(call) as? Value else {
      throw Failure.mismatchedResponseType(method: call.method, path: call.path)
    }
    return APIResponse(value: value, requestSequence: nil, serverDate: nil, deferredClientSyncMetadata: nil)
  }

  private nonisolated static func pathComponents(_ path: String) -> [Substring] {
    path.split(separator: "/", omittingEmptySubsequences: true)
  }
}

extension FakeTransport.Call {
  fileprivate init(_ request: Request<some Decodable & Sendable>) throws {
    let urlRequest = try request.makeURLRequest(baseURL: FakeTransport.baseURL, encoder: .clerkEncoder)
    guard let url = urlRequest.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw RequestError.invalidURL(path: request.path)
    }
    method = request.method
    path = components.path
    query = components.queryItems ?? []
    body = try urlRequest.httpBody.map { try JSONDecoder().decode(JSON.self, from: $0) }
    isScopedToActiveSession = urlRequest.isScopedToClerkActiveSession
  }
}
