//
//  ColorResource+Ext.swift
//  Clerk
//

#if os(iOS) || os(macOS)
#if !Xcode

import DeveloperToolsSupport
import Foundation

extension DeveloperToolsSupport.ColorResource {
  static let background = Self(name: "Background", bundle: .module)
  static let clerkDanger = Self(name: "ClerkDanger", bundle: .module)
  static let clerkMuted = Self(name: "ClerkMuted", bundle: .module)
  static let clerkNeutral = Self(name: "ClerkNeutral", bundle: .module)
  static let clerkPrimary = Self(name: "ClerkPrimary", bundle: .module)
  static let clerkPrimaryForeground = Self(name: "ClerkPrimaryForeground", bundle: .module)
  static let danger = Self(name: "Danger", bundle: .module)
  static let foreground = Self(name: "Foreground", bundle: .module)
  static let input = Self(name: "Input", bundle: .module)
  static let inputForeground = Self(name: "InputForeground", bundle: .module)
  static let muted = Self(name: "Muted", bundle: .module)
  static let mutedForeground = Self(name: "mutedForeground", bundle: .module)
  static let neutral = Self(name: "Neutral", bundle: .module)
  static let primary = Self(name: "Primary", bundle: .module)
  static let primaryForeground = Self(name: "PrimaryForeground", bundle: .module)
  static let success = Self(name: "Success", bundle: .module)
  static let warning = Self(name: "Warning", bundle: .module)
}

#endif
#endif
