//
//  ForceUpdateStatus.swift
//  Clerk
//

import Foundation

extension Clerk {
  public struct ForceUpdateStatus: Sendable, Equatable {
    public let isSupported: Bool
    public let minimumVersion: String?
    public let updateURL: URL?

    public init(
      isSupported: Bool,
      minimumVersion: String?,
      updateURL: URL?
    ) {
      self.isSupported = isSupported
      self.minimumVersion = minimumVersion
      self.updateURL = updateURL
    }
  }
}

extension Clerk.ForceUpdateStatus {
  static let supportedDefault: Self = .init(
    isSupported: true,
    minimumVersion: nil,
    updateURL: nil
  )
}
