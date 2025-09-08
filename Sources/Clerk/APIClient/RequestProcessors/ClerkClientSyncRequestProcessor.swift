//
//  ClerkClientSyncRequestProcessor.swift
//  Clerk
//
//  Created by Mike Pitre on 1/31/25.
//

import Foundation

struct ClerkClientSyncRequestProcessor: RequestPostprocessor {
  static func process(response _: HTTPURLResponse, data: Data, task _: URLSessionTask) throws {
    if let client = decodeClient(from: data) {
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
          client = responseClient
          return
        }

        if let clientClient = try? container?.decode(Client.self, forKey: .client) {
          client = clientClient
          return
        }

        // If `Client` is the top-level object, attempt direct decoding (least common)
        if let topLevelClient = try? Client(from: decoder) {
          client = topLevelClient
          return
        }

        client = nil
      }
    }

    return (try? JSONDecoder.clerkDecoder.decode(ClientWrapper.self, from: jsonData))?.client
  }
}
