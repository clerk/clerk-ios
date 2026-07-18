//
//  ClerkClientSyncResponseMiddleware.swift
//  Clerk
//

import Foundation

enum ClientResponseUpdate: Equatable {
  case client(Client)
  case explicitClear
  case absent
  case invalid
}

enum ClientSyncResponseError: Error, Equatable {
  case missingDeviceTokenForCanonicalClient
}

struct ClientSyncResponseContext {
  let update: ClientResponseUpdate
  let deviceTokenUpdate: ClerkDeviceTokenResponseUpdate
  let requestDeviceToken: String?
  let baseGeneration: UInt64?
  let serverDate: Date?
  let isCanonicalClientRequest: Bool
  let clientResponseGeneration: ClientResponseGeneration?
  let responseSequence: Int?

  func resolvedIdentityPayload(
    currentDeviceToken: String?,
    currentClient: Client?,
    currentServerDate: Date?
  ) throws -> SharedSessionIdentityPayload? {
    let payload: SharedSessionIdentityPayload
    switch update {
    case .client(let client):
      guard let token = resolvedDeviceToken else {
        if isCanonicalClientRequest {
          throw ClientSyncResponseError.missingDeviceTokenForCanonicalClient
        }
        return nil
      }
      payload = SharedSessionIdentityPayload(
        state: .present,
        deviceToken: token,
        client: client,
        serverDate: serverDate
      )
    case .explicitClear:
      payload = SharedSessionIdentityPayload(
        state: .cleared,
        deviceToken: resolvedDeviceToken,
        client: nil,
        serverDate: serverDate
      )
    case .absent:
      guard !isCanonicalClientRequest,
            case .set(let token) = deviceTokenUpdate,
            requestDeviceToken == currentDeviceToken
      else {
        return nil
      }
      payload = SharedSessionIdentityPayload(
        state: currentClient == nil ? .cleared : .present,
        deviceToken: token,
        client: currentClient,
        serverDate: serverDate ?? currentServerDate
      )
    case .invalid:
      return nil
    }
    return try payload.validated()
  }

  private var resolvedDeviceToken: String? {
    switch deviceTokenUpdate {
    case .absent:
      normalizedToken(requestDeviceToken)
    case .set(let deviceToken):
      deviceToken
    case .clear:
      nil
    }
  }

  private func normalizedToken(_ token: String?) -> String? {
    guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines),
          !token.isEmpty
    else {
      return nil
    }
    return token
  }
}

struct ClerkClientSyncResponseMiddleware: ClerkResponseMiddleware {
  private let runtimeScope: ClerkRuntimeScope

  init(runtimeScope: ClerkRuntimeScope) {
    self.runtimeScope = runtimeScope
  }

  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
    let deviceTokenUpdate = ClerkDeviceTokenResponseUpdate(
      authorizationHeader: response.value(forHTTPHeaderField: "Authorization")
    )
    let context = ClientSyncResponseContext(
      update: Self.classifyClientUpdate(
        from: data,
        isCanonicalClientRequest: request.clerkIsCanonicalClientRequest,
        deviceTokenUpdate: deviceTokenUpdate
      ),
      deviceTokenUpdate: deviceTokenUpdate,
      requestDeviceToken: request.value(forHTTPHeaderField: "Authorization"),
      baseGeneration: request.clerkSharedSessionBaseGeneration,
      serverDate: response.serverDate,
      isCanonicalClientRequest: request.clerkIsCanonicalClientRequest,
      clientResponseGeneration: request.clerkClientResponseGeneration,
      responseSequence: request.clerkRequestSequence
    )

    let clerk = try await runtimeScope.requireCurrentClerk()
    if let coordinator = await clerk.sharedSessionSyncCoordinator {
      guard context.baseGeneration != nil else {
        return
      }
      try await coordinator.handleNetworkResponse(context)
      return
    }

    try await clerk.applyLocalIdentityResponse(context)
  }

  static func classifyClientUpdate(
    from jsonData: Data,
    isCanonicalClientRequest: Bool,
    deviceTokenUpdate: ClerkDeviceTokenResponseUpdate = .absent
  ) -> ClientResponseUpdate {
    if deviceTokenUpdate == .clear {
      return .explicitClear
    }

    if let client = decodeClient(from: jsonData) {
      return .client(client)
    }

    guard let object = try? JSONSerialization.jsonObject(with: jsonData),
          let payload = object as? [String: Any]
    else {
      return .invalid
    }

    if isCanonicalClientRequest, let response = payload["response"] {
      return response is NSNull ? .absent : .invalid
    }
    if let client = payload["client"], !(client is NSNull) {
      return .invalid
    }
    if let meta = payload["meta"] as? [String: Any],
       let client = meta["client"],
       !(client is NSNull)
    {
      return .invalid
    }
    return .absent
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
}
