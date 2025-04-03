//
//  PathsV1MeSessions.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation

extension ClerkFAPI.V1Endpoint.MeEndpoint {

  var sessions: SessionsEndpoint {
    SessionsEndpoint(path: path + "/sessions")
  }

  struct SessionsEndpoint {
    /// Path: `/v1/me/sessions`
    let path: String
  }

}
