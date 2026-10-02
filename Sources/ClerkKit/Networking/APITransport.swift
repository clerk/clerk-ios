//
//  APITransport.swift
//  Clerk
//

import Foundation

protocol APITransport: Sendable {
  func send<Value: Decodable & Sendable>(_ request: Request<Value>) async throws -> APIResponse<Value>
}

extension APIClient: APITransport {}
