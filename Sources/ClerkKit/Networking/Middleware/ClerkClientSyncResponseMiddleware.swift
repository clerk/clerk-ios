//
//  ClerkClientSyncResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkClientSyncResponseMiddleware: ClerkResponseMiddleware {
  func validate(_: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
    if let client = Self.decodeClient(from: data) {
      await Clerk.shared.applyResponseClient(client, responseSequence: request.clerkRequestSequence)
    } else if hasExplicitNullClientField(in: data) {
      ClerkLogger.debug("API response explicitly returned client: null. Clearing local client state.")
      await MainActor.run {
        Clerk.shared.client = nil
      }
    }
  }

  static func decodeClient(from jsonData: Data) -> Client? {
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

        if let topLevelClient = try? Client(from: decoder) {
          client = topLevelClient
          return
        }

        client = nil
      }
    }

    return (try? JSONDecoder.clerkDecoder.decode(ClientWrapper.self, from: jsonData))?.client
  }

  private func hasExplicitNullClientField(in jsonData: Data) -> Bool {
    struct ClientFieldProbe: Decodable {
      let hasExplicitNullClientField: Bool

      enum CodingKeys: String, CodingKey {
        case client
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.client) {
          hasExplicitNullClientField = try container.decodeNil(forKey: .client)
        } else {
          hasExplicitNullClientField = false
        }
      }
    }

    return (try? JSONDecoder.clerkDecoder.decode(ClientFieldProbe.self, from: jsonData))?.hasExplicitNullClientField == true
  }
}
