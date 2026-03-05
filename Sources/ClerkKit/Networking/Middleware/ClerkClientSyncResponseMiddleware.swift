//
//  ClerkClientSyncResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkClientSyncResponseMiddleware: ClerkResponseMiddleware {
  func validate(_: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
    if let envelope = try? JSONDecoder.clerkDecoder.decode(ClientPayload.self, from: data) {
      // `/v1/client` can return a full client in `response` while `client` is null.
      // Prioritize the concrete `response` value to avoid transient clears.
      if let responseClient = envelope.responseClient {
        await setClient(responseClient, responseSequence: request.requestSequence)
        return
      }

      switch envelope.clientState {
      case let .value(client?):
        await setClient(client, responseSequence: request.requestSequence)
        return
      case .missing:
        break
      case .value(nil):
        // Intentional: do not clear client state from middleware on explicit
        // `client: null` payloads. Authoritative clears are handled explicitly
        // by auth-critical flows (for example refresh/sign-out/account delete).
        break
      }
    }

    if let client = try? JSONDecoder.clerkDecoder.decode(Client.self, from: data) {
      await setClient(client, responseSequence: request.requestSequence)
      return
    }
  }

  @MainActor
  private func setClient(_ client: Client, responseSequence: UInt64?) {
    Clerk.shared.mergeClientFromResponse(client, responseSequence: responseSequence)
  }

  /// Distinguishes explicit null from an absent key on the envelope `client` field:
  /// - `.value`: key exists and decoded as `Client?` (`nil` is intentionally ignored here).
  /// - `.missing`: key absent or undecodable (no signal).
  private enum ClientState {
    case value(Client?)
    case missing
  }

  private struct ClientPayload: Decodable {
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
        clientState = .value(client)
      } catch {
        clientState = .missing
      }
    }
  }
}
