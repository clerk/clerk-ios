//
//  EnvironmentAPI.swift
//  Clerk
//

import Foundation

package enum EnvironmentAPI {
  package static func get() -> Request<Clerk.Environment> {
    Request(path: "/v1/environment")
  }
}
