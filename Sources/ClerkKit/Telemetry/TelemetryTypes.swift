//
//  TelemetryTypes.swift
//  Clerk
//
//  Created by Mike Pitre on 8/8/25.
//

import Foundation

/// Options used to configure the telemetry collector.
///
/// Use this to control sampling, buffering, and environment metadata for
/// development-only telemetry in the Clerk iOS SDK.
struct TelemetryCollectorOptions: Sendable {
  /// Sampling rate in the range [0, 1].
  var samplingRate: Double
  /// Maximum number of events to buffer before forcing a flush.
  var maxBufferSize: Int
  /// Time interval (in seconds) between periodic flushes.
  var flushInterval: TimeInterval
  /// If true, disables all filtering (throttling and sampling) for debugging purposes.
  /// When enabled, ALL events will be recorded including duplicates and regardless of sampling rates.
  /// Buffering and flushing still apply normally.
  var disableThrottling: Bool

  /// Creates a new set of options for the telemetry collector.
  ///
  /// - Parameters:
  ///   - samplingRate: A value in \[0, 1\] controlling the global sampling rate.
  ///   - maxBufferSize: Maximum number of events to buffer before flushing.
  ///   - flushInterval: Time interval (in seconds) between periodic flushes.
  ///   - disableThrottling: If true, disables all filtering (throttling and sampling) for debugging.
  init(
    samplingRate: Double = 1.0,
    maxBufferSize: Int = 5,
    flushInterval: TimeInterval = 30.0,
    disableThrottling: Bool = false
  ) {
    self.samplingRate = samplingRate
    self.maxBufferSize = max(1, maxBufferSize)
    self.flushInterval = max(1.0, flushInterval)
    self.disableThrottling = disableThrottling
  }
}

/// A telemetry event as sent to the Clerk telemetry backend.
///
/// iOS does not include `cv` (Clerk version) or `sk` (secret key).
struct TelemetryEvent: Codable, Sendable {
  /// The event name (e.g. "method_invoked").
  let event: String
  /// The instance type string (e.g. "development", "production").
  let it: String
  /// The SDK name (e.g. "clerk-ios").
  let sdk: String
  /// The SDK version string.
  let sdkv: String
  /// The publishable key, if available.
  let pk: String?
  /// Arbitrary JSON payload for the event.
  let payload: [String: JSON]
}

/// Raw input describing a telemetry event to be recorded by the collector.
package struct TelemetryEventRaw: Sendable {
  /// The event name.
  let event: String
  /// Arbitrary JSON payload.
  let payload: [String: JSON]
  /// Optional per-event sampling rate in \[0, 1\]. If omitted, defaults to the collector `samplingRate`.
  let eventSamplingRate: Double?

  /// Creates a new raw telemetry event.
  ///
  /// - Parameters:
  ///   - event: The event name.
  ///   - payload: Arbitrary JSON payload data.
  ///   - eventSamplingRate: Optional per-event sampling override in \[0, 1\].
  init(event: String, payload: [String: JSON], eventSamplingRate: Double? = nil) {
    self.event = event
    self.payload = payload
    self.eventSamplingRate = eventSamplingRate
  }
}
