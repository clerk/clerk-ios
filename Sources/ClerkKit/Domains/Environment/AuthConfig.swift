//
//  AuthConfig.swift
//  Clerk
//

import Foundation

extension Clerk.Environment {
  public struct AuthConfig: Codable, Sendable, Equatable {
    public var singleSessionMode: Bool
  }
}
