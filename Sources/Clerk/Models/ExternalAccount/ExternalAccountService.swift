//
//  ExternalAccountService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation

extension Container {
  
  var externalAccountService: Factory<ExternalAccountService> {
    self { @MainActor in ExternalAccountService() }
  }
  
}

@MainActor
struct ExternalAccountService {
  
  var destroy: (_ externalAccountId: String) async throws -> DeletedObject = { externalAccountId in
    try await Container.shared.apiClient().request()
      .add(path: "/v1/me/external_accounts/\(externalAccountId)")
      .method(.delete)
      .addClerkSessionId()
      .data(type: ClientResponse<DeletedObject>.self)
      .async()
      .response
  }
  
} 