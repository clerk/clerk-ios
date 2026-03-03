//
//  ClerkClientSyncResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkClientSyncResponseMiddleware: ClerkAsyncResponseMiddleware {
  func validate(_: HTTPURLResponse, data: Data, for _: URLRequest) async throws {
    switch decodeClientSyncState(from: data) {
    case let .set(client):
      await MainActor.run {
        Clerk.shared.client = client
      }
    case .clear:
      await MainActor.run {
        Clerk.shared.client = nil
      }
    case .skip:
      break
    }
  }

  private enum ClientSyncState {
    case set(Client)
    case clear
    case skip
  }

  private enum Field<T> {
    case value(T)
    case null
    case missing

    static func decode<K: CodingKey>(
      from container: KeyedDecodingContainer<K>,
      forKey key: K
    ) -> Self where T: Decodable {
      guard container.contains(key) else { return .missing }
      if (try? container.decodeNil(forKey: key)) == true { return .null }
      if let value = try? container.decode(T.self, forKey: key) { return .value(value) }
      return .missing
    }
  }

  private struct ClientEnvelope: Decodable {
    let response: Field<Client>
    let client: Field<Client>

    enum CodingKeys: String, CodingKey {
      case response, client
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      response = .decode(from: container, forKey: .response)
      client = .decode(from: container, forKey: .client)
    }
  }

  private func decodeClientSyncState(from jsonData: Data) -> ClientSyncState {
    if let envelope = try? JSONDecoder.clerkDecoder.decode(ClientEnvelope.self, from: jsonData) {
      // `/v1/client` can return a full client in `response` while `client` is null.
      // Prioritize the concrete `response` value to avoid transient clears.
      if case let .value(client) = envelope.response {
        return .set(client)
      }

      switch envelope.client {
      case let .value(client):
        return .set(client)
      case .null:
        return .clear
      case .missing:
        break
      }
    }

    if let client = try? JSONDecoder.clerkDecoder.decode(Client.self, from: jsonData) {
      return .set(client)
    }

    return .skip
  }
}
