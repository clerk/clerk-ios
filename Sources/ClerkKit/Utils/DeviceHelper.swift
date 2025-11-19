//
//  DeviceHelper.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Provides device-related information for the current device.
enum DeviceHelper {
  /// The device's vendor identifier UUID string.
  ///
  /// Returns `nil` if unavailable or on watchOS/macOS.
  @MainActor
  static var deviceID: String? {
    #if !os(watchOS) && !os(macOS)
    UIDevice.current.identifierForVendor?.uuidString
    #else
    nil
    #endif
  }

  /// The device's interface type based on `UIDevice.userInterfaceIdiom`.
  ///
  /// Returns one of: "ipad", "iphone", "mac", "carplay", "tv", "vision", "watch", or "unspecified".
  @MainActor
  static var deviceType: String {
    #if os(watchOS)
    return "watch"
    #elseif canImport(UIKit)
    switch UIDevice.current.userInterfaceIdiom {
    case .pad:
      return "ipad"
    case .phone:
      return "iphone"
    case .mac:
      return "mac"
    case .carPlay:
      return "carplay"
    case .tv:
      return "tv"
    case .vision:
      return "vision"
    case .unspecified:
      fallthrough
    @unknown default:
      return "unspecified"
    }
    #else
    return "unspecified"
    #endif
  }

  /// The device's model name (e.g., "iPhone15,2").
  static var deviceModel: String {
    #if canImport(UIKit)
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    return machineMirror.children.reduce("") { identifier, element in
      guard let value = element.value as? Int8, value != 0 else { return identifier }
      return identifier + String(UnicodeScalar(UInt8(value)))
    }
    #else
    return ""
    #endif
  }

  /// The operating system version (e.g., "17.0.0").
  static var osVersion: String {
    let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
    return String(
      format: "%ld.%ld.%ld",
      arguments: [systemVersion.majorVersion, systemVersion.minorVersion, systemVersion.patchVersion]
    )
  }

  /// The app's version string from Info.plist.
  static var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
  }

  /// The app's bundle identifier.
  static var bundleID: String {
    Bundle.main.bundleIdentifier ?? ""
  }

  /// Returns "true" if running in simulator or TestFlight, "false" otherwise.
  static var isSandbox: String {
    #if targetEnvironment(simulator)
    return "true"
    #else
    guard let url = Bundle.main.appStoreReceiptURL else {
      return "false"
    }
    return "\(url.path.contains("sandboxReceipt"))"
    #endif
  }
}
