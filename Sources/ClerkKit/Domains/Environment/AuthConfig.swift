//
//  AuthConfig.swift
//  Clerk
//

import Foundation

extension Clerk.Environment {
  public struct AuthConfig: Codable, Sendable, Equatable {
    public var singleSessionMode: Bool

    /// Whether the instance serves session tokens through the session minter.
    public var sessionMinter: Bool

    init(singleSessionMode: Bool, sessionMinter: Bool = false) {
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
