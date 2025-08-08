//
//  TelemetryTypes.swift
//  Clerk
//
//  Created by AI Assistant on 2025-08-08.
//

import Foundation

/// Options used to configure the telemetry collector.
///
/// Use this to control sampling, buffering, and environment metadata for
/// development-only telemetry in the Clerk iOS SDK.
struct TelemetryCollectorOptions: Sendable {
    /// Sampling rate in the range [0, 1].
    public var samplingRate: Double
    /// Maximum number of events to buffer before forcing a flush.
    public var maxBufferSize: Int

    /// Creates a new set of options for the telemetry collector.
    ///
    /// - Parameters:
    ///   - samplingRate: A value in \[0, 1\] controlling the global sampling rate.
    ///   - maxBufferSize: Maximum number of events to buffer before flushing.
    public init(
        samplingRate: Double = 1.0,
        maxBufferSize: Int = 5
    ) {
        self.samplingRate = samplingRate
        self.maxBufferSize = max(1, maxBufferSize)
    }
}


/// A telemetry event as sent to the Clerk telemetry backend.
///
/// iOS does not include `cv` (Clerk version) or `sk` (secret key).
struct TelemetryEvent: Codable, Sendable {
    /// The event name (e.g. "method_invoked").
    public let event: String
    /// The instance type string (e.g. "development", "production").
    public let it: String
    /// The SDK name (e.g. "clerk-ios").
    public let sdk: String
    /// The SDK version string.
    public let sdkv: String
    /// The publishable key, if available.
    public let pk: String?
    /// Arbitrary JSON payload for the event.
    public let payload: [String: JSON]
}

/// Raw input describing a telemetry event to be recorded by the collector.
struct TelemetryEventRaw: Sendable {
    /// The event name.
    public let event: String
    /// Arbitrary JSON payload.
    public let payload: [String: JSON]
    /// Optional per-event sampling rate in \[0, 1\]. If omitted, defaults to the collector `samplingRate`.
    public let eventSamplingRate: Double?

    /// Creates a new raw telemetry event.
    ///
    /// - Parameters:
    ///   - event: The event name.
    ///   - payload: Arbitrary JSON payload data.
    ///   - eventSamplingRate: Optional per-event sampling override in \[0, 1\].
    public init(event: String, payload: [String: JSON], eventSamplingRate: Double? = nil) {
        self.event = event
        self.payload = payload
        self.eventSamplingRate = eventSamplingRate
    }
}
