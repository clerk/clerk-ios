//
//  ClientContainer.swift
//  Clerk
//
//  Created by Mike Pitre on 2/23/25.
//

import Factory
import Foundation

final class ClientContainer: SharedContainer {
  public static let shared = ClientContainer()
  public let manager = ContainerManager()
  
  var get: Factory<() async throws -> Client?> {
    self {{
      let request = ClerkFAPI.v1.client.get
      return try await Clerk.shared.apiClient.send(request).value.response
    }}
  }
}
