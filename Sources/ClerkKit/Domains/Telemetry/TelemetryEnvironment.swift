//
//  TelemetryEnvironment.swift
//  Clerk
//
//  Created by Mike Pitre on 8/13/25.
//

import Foundation

/// Abstracts environment-specific data needed by telemetry.
///
/// This protocol intentionally contains no references to `Clerk` so that
/// the telemetry system can be decoupled from the core SDK types.
protocol TelemetryEnvironmentProviding: Sendable {
  // Static SDK identity
  var sdkName: String { get }
  var sdkVersion: String { get }

  // Dynamic environment signals
  func instanceTypeString() async -> String
  func isTelemetryEnabled() async -> Bool
  func isDebugModeEnabled() async -> Bool
  func publishableKey() async -> String?
}

/// Default environment provider backed by the `Clerk` singleton.
struct ClerkTelemetryEnvironment: TelemetryEnvironmentProviding {
  var sdkName: String { "clerk-ios" }
  var sdkVersion: String { Clerk.version }

  func instanceTypeString() async -> String {
    await Clerk.shared.instanceType.rawValue
  }

  func isTelemetryEnabled() async -> Bool {
    await Clerk.shared.options.telemetryEnabled
  }

  func isDebugModeEnabled() async -> Bool {
    await Clerk.shared.options.debugMode
  }

  func publishableKey() async -> String? {
    let key = await Clerk.shared.publishableKey
    return key.isEmpty ? nil : key
  }
}


