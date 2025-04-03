//
//  PathsV1Environment.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint {

  var environment: EnvironmentEndpoint {
    EnvironmentEndpoint(path: path + "/environment")
  }

  struct EnvironmentEndpoint {
    /// Path: `v1/environment`
    let path: String

    var get: Request<Clerk.Environment> {
      .init(path: path)
    }
  }

}
