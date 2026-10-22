//
//  AppVersionSupportStatus.swift
//  Clerk
//

import Foundation

extension Clerk {
  /// Whether this build of your app meets the minimum version set for it in the Clerk Dashboard.
  ///
  /// When the version is unsupported, Clerk rejects your app's requests until the user updates.
  /// On iOS and macOS, ClerkKitUI shows its update-required screen automatically; set
  /// ``Clerk/Options/updateRequiredViewEnabled`` to `false` to show your own UI instead.
  /// On watchOS, tvOS and visionOS, show your own UI from this status.
  public struct AppVersionSupportStatus: Sendable, Equatable {
    /// Whether this app version is supported.
    public let isSupported: Bool

    /// This build's version, its `CFBundleShortVersionString`.
    public let currentVersion: String

    /// The oldest supported version, when a minimum is set for this app.
    public let minimumVersion: String?

    /// The App Store page to send users to so they can update.
    public let updateURL: URL?

    public init(
      isSupported: Bool,
      currentVersion: String,
      minimumVersion: String?,
      updateURL: URL?
    ) {
      self.isSupported = isSupported
      self.currentVersion = currentVersion
      self.minimumVersion = minimumVersion
      self.updateURL = updateURL
    }
  }
}

extension Clerk.AppVersionSupportStatus {
  static func supported(currentVersion: String) -> Self {
    .init(isSupported: true, currentVersion: currentVersion, minimumVersion: nil, updateURL: nil)
  }
}
