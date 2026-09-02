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
    requestBundleID: String?,
    requestVersion: String?
  ) -> Clerk.AppVersionSupportStatus? {
    guard let meta,
          meta["platform"]?.stringValue.nilIfEmpty?.lowercased() == "ios",
          let normalizedBundleID = requestBundleID.flatMap(normalizeIdentifier),
          let appIdentifier = meta["app_identifier"]?.stringValue,
          normalizeIdentifier(appIdentifier) == normalizedBundleID,
          let requestVersion,
          let returnedCurrentVersion = meta["current_version"]?.stringValue,
          returnedCurrentVersion == requestVersion,
          AppVersionComparator.isValid(requestVersion),
          let minimumVersion = meta["minimum_version"]?.stringValue.nilIfEmpty,
          AppVersionComparator.isValid(minimumVersion),
          AppVersionComparator.compare(requestVersion, minimumVersion) == -1,
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
