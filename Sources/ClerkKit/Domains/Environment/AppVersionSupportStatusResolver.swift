//
//  AppVersionSupportStatusResolver.swift
//  Clerk
//

import Foundation

enum AppVersionSupportStatusResolver {
  static func resolve(
    environment: Clerk.Environment?,
    bundleID: String,
    currentVersion: String
  ) -> Clerk.AppVersionSupportStatus {
    let normalizedCurrentVersion = (currentVersion as String?).nilIfEmpty

    guard let policy = policy(for: bundleID, environment: environment) else {
      return .init(
        isSupported: true,
        minimumVersion: nil,
        updateURL: nil
      )
    }

    let minimumVersion = (policy.minimumVersion as String?).nilIfEmpty
    let updateURL = policy.updateUrl.flatMap { URL(string: $0) }

    guard let minimumVersion else {
      return .init(
        isSupported: true,
        minimumVersion: nil,
        updateURL: updateURL
      )
    }

    guard let normalizedCurrentVersion else {
      return .init(
        isSupported: true,
        minimumVersion: minimumVersion,
        updateURL: updateURL
      )
    }

    guard AppVersionComparator.isValid(normalizedCurrentVersion) else {
      return .init(
        isSupported: true,
        minimumVersion: minimumVersion,
        updateURL: updateURL
      )
    }

    guard AppVersionComparator.isValid(minimumVersion) else {
      return .init(
        isSupported: true,
        minimumVersion: minimumVersion,
        updateURL: updateURL
      )
    }

    let isSupported = AppVersionComparator.isSupported(
      current: normalizedCurrentVersion,
      minimum: minimumVersion
    ) ?? true

    return .init(
      isSupported: isSupported,
      minimumVersion: minimumVersion,
      updateURL: updateURL
    )
  }

  static func resolveFromUnsupportedAppVersionMeta(
    _ meta: JSON?,
    bundleID: String
  ) -> Clerk.AppVersionSupportStatus? {
    guard let meta else { return nil }

    if let platform = meta["platform"]?.stringValue?.lowercased(),
       platform != "ios"
    {
      return nil
    }

    let normalizedBundleID = normalizeIdentifier(bundleID)

    if let appIdentifier = meta["app_identifier"]?.stringValue,
       let normalizedAppIdentifier = normalizeIdentifier(appIdentifier),
       normalizedBundleID != nil,
       normalizedAppIdentifier != normalizedBundleID
    {
      return nil
    }

    let minimumVersion = meta["minimum_version"]?.stringValue.nilIfEmpty
    let updateURL = meta["update_url"]?.stringValue.nilIfEmpty.flatMap { URL(string: $0) }

    return .init(
      isSupported: false,
      minimumVersion: minimumVersion,
      updateURL: updateURL
    )
  }

  private static func policy(
    for bundleID: String,
    environment: Clerk.Environment?
  ) -> Clerk.Environment.MinimumSupportedVersion.IOSPolicy? {
    guard let normalizedBundleID = normalizeIdentifier(bundleID) else { return nil }
    return environment?.nativeAppSettings.minimumSupportedVersion.ios.first { policy in
      normalizeIdentifier(policy.bundleId) == normalizedBundleID
    }
  }

  private static func normalizeIdentifier(_ value: String) -> String? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty ? nil : normalized
  }
}
