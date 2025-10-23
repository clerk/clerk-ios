//
//  ClerkClientSyncResponseMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/31/25.
//

import Foundation

struct ClerkClientSyncResponseMiddleware: NetworkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
    if let client = Self.decodeClient(from: data) {
      Task { @MainActor in
        Clerk.shared.client = client
      }
    }
  }

  private static func decodeClient(from jsonData: Data) -> Client? {
    struct ClientWrapper: Decodable {
      let client: Client?

      enum CodingKeys: String, CodingKey {
        case response, client
      }

      init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)

        if let responseClient = try? container?.decode(Client.self, forKey: .response) {
          self.client = responseClient
          return
        }

        if let clientClient = try? container?.decode(Client.self, forKey: .client) {
          self.client = clientClient
          return
        }

        if let topLevelClient = try? Client(from: decoder) {
          self.client = topLevelClient
          return
        }

        self.client = nil
      }
    }

    return (try? JSONDecoder.clerkDecoder.decode(ClientWrapper.self, from: jsonData))?.client
  }
}
