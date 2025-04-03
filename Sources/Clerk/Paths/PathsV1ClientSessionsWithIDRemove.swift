//
//  PathsV1ClientSessionsWithIDRemove.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint.SessionsEndpoint.WithIdEndpoint {

  var remove: RemoveEndpoint {
    RemoveEndpoint(path: path + "/remove")
  }

  struct RemoveEndpoint {
    /// Path: `v1/client/sessions/{id}/remove`
    let path: String

    var post: Request<ClientResponse<Session>> {
      .init(path: path, method: .post)
    }
  }

}
