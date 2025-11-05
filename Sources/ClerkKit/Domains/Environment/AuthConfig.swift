//
//  AuthConfig.swift
//  Clerk
//
//  Created by Mike Pitre on 8/2/24.
//

import Foundation

public extension Clerk.Environment {
  struct AuthConfig: Codable, Sendable, Equatable {
    public var singleSessionMode: Bool
  }
}
