//
//  ForceUpdate.swift
//

import Foundation

extension Clerk.Environment {
  public struct ForceUpdate: Codable, Equatable, Sendable {
    public var required: Bool
    public var minimumAppVersion: String?
    public var appStoreURL: URL?

    public init(
      required: Bool = false,
      minimumAppVersion: String? = nil,
      appStoreURL: URL? = nil
    ) {
      self.required = required
      self.minimumAppVersion = minimumAppVersion
      self.appStoreURL = appStoreURL
    }

    public static let empty = Self()

    enum CodingKeys: String, CodingKey {
      case required
      case minimumAppVersion
      case appStoreURL = "appStoreUrl"
    }
  }
}
