//
//  AppVersionSupportStatusResolver.swift
//  Clerk
//

import Foundation

enum AppVersionSupportStatusResolver {
  private struct ResolvedIOSPolicy {
    let minimumVersion: String
    let updateURL: URL
  }

  static func resolve(
    environment: Clerk.Environment?,
    bundleID: String,
    currentVersion: String
  ) -> Clerk.AppVersionSupportStatus {
    guard let policy = policy(for: bundleID, environment: environment) else {
      return .supportedDefault
    }

    guard AppVersionComparator.isValid(currentVersion),
          let isSupported = AppVersionComparator.isSupported(
            current: currentVersion,
            minimum: policy.minimumVersion
          )
    else {
      return .init(
        isSupported: true,
        minimumVersion: policy.minimumVersion,
        updateURL: policy.updateURL
      )
    }

    return .init(
      isSupported: isSupported,
      minimumVersion: policy.minimumVersion,
      updateURL: policy.updateURL
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

    guard let minimumVersion = meta["minimum_version"]?.stringValue.nilIfEmpty,
          AppVersionComparator.isValid(minimumVersion),
          let updateURLValue = meta["update_url"]?.stringValue.nilIfEmpty,
          let updateURL = validHTTPURL(updateURLValue)
    else {
      return nil
    }

    return .init(
      isSupported: false,
      minimumVersion: minimumVersion,
      updateURL: updateURL
    )
  }

  private static func policy(
    for bundleID: String,
    environment: Clerk.Environment?
  ) -> ResolvedIOSPolicy? {
    guard let normalizedBundleID = normalizeIdentifier(bundleID) else { return nil }

    return environment?.nativeAppSettings.minimumSupportedVersion.ios.reduce(nil) { strictest, policy in
      guard normalizeIdentifier(policy.bundleId) == normalizedBundleID else { return strictest }

      let minimumVersion = policy.minimumVersion.trimmingCharacters(in: .whitespacesAndNewlines)
      guard AppVersionComparator.isValid(minimumVersion),
            let updateURLValue = policy.updateUrl,
            let updateURL = validHTTPURL(updateURLValue)
      else {
        return strictest
      }

      let candidate = ResolvedIOSPolicy(
        minimumVersion: minimumVersion,
        updateURL: updateURL
      )
      guard let strictest else { return candidate }
      return AppVersionComparator.compare(candidate.minimumVersion, strictest.minimumVersion) == 1
        ? candidate
        : strictest
    }
  }

  private static func normalizeIdentifier(_ value: String) -> String? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty ? nil : normalized
  }

  private static func validHTTPURL(_ value: String) -> URL? {
    guard let url = URL(string: value),
          let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme),
          url.host != nil
    else {
      return nil
    }
    return url
  }
}
