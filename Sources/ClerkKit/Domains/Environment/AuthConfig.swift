//
//  AuthConfig.swift
//  Clerk
//

import Foundation

extension Clerk.Environment {
  public struct AuthConfig: Codable, Sendable, Equatable {
    public var singleSessionMode: Bool
    public var sessionMinter: Bool

    public init(
      singleSessionMode: Bool,
      sessionMinter: Bool = false
    ) {
      self.singleSessionMode = singleSessionMode
      self.sessionMinter = sessionMinter
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      singleSessionMode = try container.decode(Bool.self, forKey: .singleSessionMode)
      sessionMinter = try container.decodeIfPresent(Bool.self, forKey: .sessionMinter) ?? false
    }
  }
}
