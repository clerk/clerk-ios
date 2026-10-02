//
//  ClientResponse.swift
//  Clerk
//

import Foundation

package struct ClientResponse<Response: Codable & Sendable>: Codable {
  package let response: Response
  package let client: Client?

  package init(response: Response, client: Client?) {
    self.response = response
    self.client = client
  }
}
