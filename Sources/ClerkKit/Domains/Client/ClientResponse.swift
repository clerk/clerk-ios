//
//  ClientResponse.swift
//  Clerk
//

import Foundation

struct ClientResponse<Response: Codable & Sendable>: Codable {
  let response: Response
  let client: Client?
}
