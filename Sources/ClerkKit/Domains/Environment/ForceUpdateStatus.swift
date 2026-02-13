//
//  ForceUpdateStatus.swift
//  Clerk
//

import Foundation

extension Clerk {
  public struct ForceUpdateStatus: Sendable, Equatable {
    public enum Reason: String, Sendable, Equatable {
      case supported
      case noPolicy
      case missingCurrentVersion
      case invalidCurrentVersion
      case invalidMinimumVersion
      case belowMinimum
      case serverRejected
    }

    public let isSupported: Bool
    public let currentVersion: String?
    public let minimumVersion: String?
    public let updateURL: URL?
    public let reason: Reason

    public init(
      isSupported: Bool,
      currentVersion: String?,
      minimumVersion: String?,
      updateURL: URL?,
      reason: Reason
    ) {
      self.isSupported = isSupported
      self.currentVersion = currentVersion
      self.minimumVersion = minimumVersion
      self.updateURL = updateURL
      self.reason = reason
    }
  }
}

extension Clerk.ForceUpdateStatus {
  static let supportedDefault: Self = .init(
    isSupported: true,
    currentVersion: (DeviceHelper.appVersion as String?).nilIfEmpty,
    minimumVersion: nil,
    updateURL: nil,
    reason: .noPolicy
  )
}
