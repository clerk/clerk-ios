//
//  ClerkClientSyncResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkClientSyncResponseMiddleware: ClerkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
    if let envelope = try? JSONDecoder.clerkDecoder.decode(ClientPayload.self, from: data) {
      // `/v1/client` can return a full client in `response` while `client` is null.
      // Prioritize the concrete `response` value to avoid transient clears.
      if let responseClient = envelope.responseClient {
        await setClient(responseClient, responseSequence: request.requestSequence)
        await applyAuthoritativeClearIfNeeded(response: response, request: request)
        return
      }

      switch envelope.clientState {
      case let .value(client?):
        await setClient(client, responseSequence: request.requestSequence)
        await applyAuthoritativeClearIfNeeded(response: response, request: request)
        return
      case .missing:
        break
      case .value(nil):
        // Intentional: do not clear for generic `client: null` payloads.
        // Authoritative clear is only applied for specific auth routes below.
        break
      }
    }

    if let client = try? JSONDecoder.clerkDecoder.decode(Client.self, from: data) {
      await setClient(client, responseSequence: request.requestSequence)
    }

    await applyAuthoritativeClearIfNeeded(response: response, request: request)
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

  @MainActor
  private func setClient(_ client: Client, responseSequence: UInt64?) {
    Clerk.shared.mergeClientFromResponse(client, responseSequence: responseSequence)
  }

  @MainActor
  private func applyAuthoritativeClearIfNeeded(response: HTTPURLResponse, request: URLRequest) async {
    guard (200 ... 299).contains(response.statusCode) else {
      return
    }

    guard let path = request.url?.path else {
      return
    }

    let responseSequence = request.requestSequence

    if request.httpMethod == HTTPMethod.delete.rawValue,
       path == "/v1/client/sessions"
    {
      await Clerk.shared.applyAuthoritativeClear(
        responseSequence: responseSequence,
        flush: true,
        requiresOrderingProof: true
      )
      return
    }

    if request.httpMethod == HTTPMethod.post.rawValue,
       path.hasPrefix("/v1/client/sessions/"),
       path.hasSuffix("/remove"),
       Clerk.shared.client?.sessions.isEmpty ?? true
    {
      await Clerk.shared.applyAuthoritativeClear(
        responseSequence: responseSequence,
        flush: true,
        requiresOrderingProof: true
      )
    }
  }
}
