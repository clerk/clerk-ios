//
//  ClientService.swift
//  Clerk
//
//  Created by Mike Pitre on 2/26/25.
//

import Foundation
import Factory

struct ClientService {
  var get: () async throws -> Client?
}

extension ClientService {
  
  static var liveValue: Self {
    .init(
      get: {
        let request = ClerkFAPI.v1.client.get
        return try await Clerk.shared.apiClient.send(request).value.response
      }
    )
  }
  
}

extension Container {
  
  var clientService: Factory<ClientService> {
    self { .liveValue }
  }
  
}
