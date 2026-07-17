//
//  ClerkClientSyncResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkClientSyncResponseMiddleware: ClerkResponseMiddleware {
  private let runtimeScope: ClerkRuntimeScope

  init(runtimeScope: ClerkRuntimeScope) {
    self.runtimeScope = runtimeScope
  }

  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
    let responseSequence = request.clerkRequestSequence
    let serverDate = response.serverDate
    let deviceToken = response.value(forHTTPHeaderField: "Authorization")

    if let client = Self.decodeClient(from: data) {
      _ = try await runtimeScope.withCurrentClerk {
        $0.applyResponseClient(
          client,
          responseSequence: responseSequence,
          serverDate: serverDate,
          clientResponseGeneration: request.clerkClientResponseGeneration,
          responseDeviceToken: deviceToken
        )
      }
    } else if Self.hasExplicitNullClientField(in: data) {
      ClerkLogger.debug("API response explicitly returned client: null. Clearing local client state.")
      _ = try await runtimeScope.withCurrentClerk {
        $0.applyResponseClient(
          nil,
          responseSequence: responseSequence,
          serverDate: serverDate,
          clientResponseGeneration: request.clerkClientResponseGeneration,
          responseDeviceToken: deviceToken
        )
      }
    }
  }

  static func containsClientUpdate(in jsonData: Data) -> Bool {
    decodeClient(from: jsonData) != nil
      || containsClientField(in: jsonData)
  }

  static func decodeClient(from jsonData: Data) -> Client? {
    struct ClientWrapper: Decodable {
      let client: Client?

      enum CodingKeys: String, CodingKey {
        case response, client, meta
      }

      enum MetaCodingKeys: String, CodingKey {
        case client
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

        if let metaContainer = try? container?.nestedContainer(keyedBy: MetaCodingKeys.self, forKey: .meta),
           let metaClient = try? metaContainer.decode(Client.self, forKey: .client)
        {
          client = metaClient
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

  private static func hasExplicitNullClientField(in jsonData: Data) -> Bool {
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

  private static func containsClientField(in jsonData: Data) -> Bool {
    guard let object = try? JSONSerialization.jsonObject(with: jsonData),
          let payload = object as? [String: Any]
    else {
      return false
    }

    if payload.keys.contains("client") {
      return true
    }

    guard let metaClient = (payload["meta"] as? [String: Any])?["client"] else {
      return false
    }

    return !(metaClient is NSNull)
  }
}
