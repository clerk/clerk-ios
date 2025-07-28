//
//  ClientService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation

extension Container {
  
  var clientService: Factory<ClientService> {
    self { @MainActor in ClientService() }
  }
  
}

@MainActor
struct ClientService {
  
  var get: () async throws -> Client? = {
    try await Container.shared.apiClient().request()
      .add(path: "/v1/client")
      .data(type: ClientResponse<Client?>.self)
      .async()
      .response
  }
  
} 