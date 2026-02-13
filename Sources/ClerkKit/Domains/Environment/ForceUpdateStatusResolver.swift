//
//  ForceUpdateStatusResolver.swift
//  Clerk
//

import Foundation

enum ForceUpdateStatusResolver {
  static func resolve(
    environment: Clerk.Environment?,
    bundleID: String,
    currentVersion: String
  ) -> Clerk.ForceUpdateStatus {
    let normalizedCurrentVersion = (currentVersion as String?).nilIfEmpty

    guard let policy = policy(for: bundleID, environment: environment) else {
      return .init(
        isSupported: true,
        currentVersion: normalizedCurrentVersion,
        minimumVersion: nil,
        updateURL: nil,
        reason: .noPolicy
      )
    }

    let minimumVersion = (policy.minimumVersion as String?).nilIfEmpty
    let updateURL = policy.updateUrl.flatMap { URL(string: $0) }

    guard let minimumVersion else {
      return .init(
        isSupported: true,
        currentVersion: normalizedCurrentVersion,
        minimumVersion: nil,
        updateURL: updateURL,
        reason: .noPolicy
      )
    }

    guard let normalizedCurrentVersion else {
      return .init(
        isSupported: true,
        currentVersion: nil,
        minimumVersion: minimumVersion,
        updateURL: updateURL,
        reason: .missingCurrentVersion
      )
    }

    guard AppVersionComparator.isValid(normalizedCurrentVersion) else {
      return .init(
        isSupported: true,
        currentVersion: normalizedCurrentVersion,
        minimumVersion: minimumVersion,
        updateURL: updateURL,
        reason: .invalidCurrentVersion
      )
    }

    guard AppVersionComparator.isValid(minimumVersion) else {
      return .init(
        isSupported: true,
        currentVersion: normalizedCurrentVersion,
        minimumVersion: minimumVersion,
        updateURL: updateURL,
        reason: .invalidMinimumVersion
      )
    }

    let isSupported = AppVersionComparator.isSupported(
      current: normalizedCurrentVersion,
      minimum: minimumVersion
    ) ?? true

    return .init(
      isSupported: isSupported,
      currentVersion: normalizedCurrentVersion,
      minimumVersion: minimumVersion,
      updateURL: updateURL,
      reason: isSupported ? .supported : .belowMinimum
    )
  }

  static func resolveFromUnsupportedAppVersionMeta(
    _ meta: JSON?,
    bundleID: String
  ) -> Clerk.ForceUpdateStatus? {
    guard let meta else { return nil }

    if let platform = meta["platform"]?.stringValue?.lowercased(),
       platform != "ios"
    {
      return nil
    }

    if let appIdentifier = meta["app_identifier"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
       !appIdentifier.isEmpty,
       !bundleID.isEmpty,
       appIdentifier != bundleID
    {
      return nil
    }

    let currentVersion = meta["current_version"]?.stringValue.nilIfEmpty
    let minimumVersion = meta["minimum_version"]?.stringValue.nilIfEmpty
    let updateURL = meta["update_url"]?.stringValue.nilIfEmpty.flatMap { URL(string: $0) }

    return .init(
      isSupported: false,
      currentVersion: currentVersion,
      minimumVersion: minimumVersion,
      updateURL: updateURL,
      reason: .serverRejected
    )
  }

  private static func policy(
    for bundleID: String,
    environment: Clerk.Environment?
  ) -> Clerk.Environment.ForceUpdate.IOSPolicy? {
    let normalizedBundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedBundleID.isEmpty else { return nil }
    return environment?.forceUpdate?.ios.first { policy in
      policy.bundleId == normalizedBundleID
    }
  }
}
