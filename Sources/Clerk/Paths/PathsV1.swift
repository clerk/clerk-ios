//
//  PathsV1.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation

extension ClerkFAPI {
  static var v1: V1Endpoint {
    V1Endpoint(path: "/v1")
  }

  struct V1Endpoint {
    /// Path: `/v1`
    let path: String
  }
}
