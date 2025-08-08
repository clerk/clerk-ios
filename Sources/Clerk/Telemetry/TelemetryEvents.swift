//
//  TelemetryEvents.swift
//  Clerk
//
//  Created by AI Assistant on 2025-08-08.
//

import Foundation

/// Helper builders for common telemetry events.
enum TelemetryEvents {
    private static let defaultSamplingRate: Double = 0.1

    /// Create an event for when a method is invoked.
    /// - Parameters:
    ///   - method: A stable method identifier (e.g., "signIn", "getToken").
    ///   - payload: Additional payload data.
    /// - Returns: A raw telemetry event ready to be recorded.
    static func methodInvoked(
        _ method: String,
        payload: [String: JSON] = [:]
    ) -> TelemetryEventRaw {
        var body: [String: JSON] = ["method": .string(method)]
        body.merge(payload, uniquingKeysWith: { _, new in new })

        return TelemetryEventRaw(
            event: "METHOD_INVOKED",
            payload: body,
            eventSamplingRate: defaultSamplingRate
        )
    }

    /// Create an event for when a view has appeared.
    /// - Parameters:
    ///   - viewName: The view or screen identifier (e.g., "SignInView").
    ///   - payload: Additional payload data.
    /// - Returns: A raw telemetry event ready to be recorded.
    static func viewDidAppear(
        _ viewName: String,
        payload: [String: JSON] = [:]
    ) -> TelemetryEventRaw {
        var body: [String: JSON] = ["view": .string(viewName)]
        body.merge(payload, uniquingKeysWith: { _, new in new })

        return TelemetryEventRaw(
            event: "VIEW_DID_APPEAR",
            payload: body,
            eventSamplingRate: defaultSamplingRate
        )
    }

    /// Create an event to attach framework/host metadata.
    /// - Parameter metadata: Arbitrary metadata (e.g., OS version, device).
    /// - Returns: A raw telemetry event ready to be recorded.
    static func frameworkMetadata(
        _ metadata: [String: JSON]
    ) -> TelemetryEventRaw {
        TelemetryEventRaw(
            event: "FRAMEWORK_METADATA",
            payload: metadata,
            eventSamplingRate: defaultSamplingRate
        )
    }
}


