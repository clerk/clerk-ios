//
//  AppVersionSupportStatusResolver.swift
//  Clerk
//

import Foundation

enum AppVersionSupportStatusResolver {
  static func resolve(
    environment: Clerk.Environment,
    bundleID: String,
    currentVersion: String
  ) -> Clerk.AppVersionSupportStatus {
    guard let policy = environment.nativeAppSettings.minimumSupportedVersion.ios.first(where: { $0.bundleId == bundleID }) else {
      return .supported(currentVersion: currentVersion)
    }

    let isSupported = AppVersionComparator.isSupported(current: currentVersion, minimum: policy.minimumVersion) ?? true
    return .init(
      isSupported: isSupported,
      currentVersion: currentVersion,
      minimumVersion: policy.minimumVersion,
      updateURL: policy.updateUrl.flatMap(storeURL)
    )
  }

  static func resolve(
    unsupportedAppVersionMeta meta: JSON?,
    currentVersion: String,
    environmentStatus: Clerk.AppVersionSupportStatus? = nil
  ) -> Clerk.AppVersionSupportStatus {
    .init(
      isSupported: false,
      currentVersion: meta?["current_version"]?.stringValue ?? currentVersion,
      minimumVersion: meta?["minimum_version"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 } ?? environmentStatus?.minimumVersion,
      updateURL: meta?["update_url"]?.stringValue.flatMap(storeURL) ?? environmentStatus?.updateURL
    )
  }

  private static func storeURL(_ value: String) -> URL? {
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
