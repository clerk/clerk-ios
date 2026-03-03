//
//  ClerkClientSyncResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkClientSyncResponseMiddleware: ClerkResponseMiddleware {
  func validate(_: HTTPURLResponse, data: Data, for _: URLRequest) async throws {
    if let envelope = try? JSONDecoder.clerkDecoder.decode(ClientEnvelope.self, from: data) {
      // `/v1/client` can return a full client in `response` while `client` is null.
      // Prioritize the concrete `response` value to avoid transient clears.
      if let responseClient = envelope.responseClient {
        await setClient(responseClient)
        return
      }

      switch envelope.clientState {
      case let .value(client):
        await setClient(client)
        return
      case .null:
        await setClient(nil)
        return
      case .missing:
        break
      }
    }

    if let client = try? JSONDecoder.clerkDecoder.decode(Client.self, from: data) {
      await setClient(client)
      return
    }
  }

  @MainActor
  private func setClient(_ client: Client?) {
    Clerk.shared.client = client
  }

  /// Distinguishes explicit null from an absent key on the envelope `client` field:
  /// - `.value`: key exists and decoded as `Client`.
  /// - `.null`: key exists and is explicitly null (intentional clear signal).
  /// - `.missing`: key absent or undecodable (no signal; do not clear by itself).
  private enum ClientState {
    case value(Client)
    case null
    case missing
  }

  private struct ClientEnvelope: Decodable {
    let responseClient: Client?
    let clientState: ClientState

    enum CodingKeys: String, CodingKey {
      case response, client
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      responseClient = try? container.decode(Client.self, forKey: .response)

      guard container.contains(.client) else {
        clientState = .missing
        return
      }

      do {
        let client = try container.decodeIfPresent(Client.self, forKey: .client)
        clientState = client.map(ClientState.value) ?? .null
      } catch {
        clientState = .missing
      }
    }
  }
}
