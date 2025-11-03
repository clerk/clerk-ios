//
//  TelemetryEvents.swift
//  Clerk
//
//  Created by Mike Pitre on 8/8/25.
//

import Foundation

/// Helper builders for common telemetry events.
package enum TelemetryEvents {
  // Sampling rates matching JavaScript version
  private static let methodInvokedSamplingRate: Double = 0.1
  private static let viewDidAppearSamplingRate: Double = 0.1

  /// Create an event for when a method is invoked.
  /// - Parameters:
  ///   - method: A stable method identifier (e.g., "signIn", "getToken").
  ///   - payload: Additional payload data.
  ///   - samplingRate: Optional custom sampling rate. If nil, uses the default for this event type.
  /// - Returns: A raw telemetry event ready to be recorded.
  static func methodInvoked(
    _ method: String,
    payload: [String: JSON] = [:],
    samplingRate: Double? = nil
  ) -> TelemetryEventRaw {
    var body: [String: JSON] = ["method": .string(method)]
    body.merge(payload, uniquingKeysWith: { _, new in new })

    return TelemetryEventRaw(
      event: "METHOD_INVOKED",
      payload: body,
      eventSamplingRate: samplingRate ?? methodInvokedSamplingRate
    )
  }

  /// Create an event for when a view has appeared.
  /// - Parameters:
  ///   - viewName: The view or screen identifier (e.g., "SignInView").
  ///   - payload: Additional payload data.
  ///   - samplingRate: Optional custom sampling rate. If nil, uses the default for this event type.
  /// - Returns: A raw telemetry event ready to be recorded.
  package static func viewDidAppear(
    _ viewName: String,
    payload: [String: JSON] = [:],
    samplingRate: Double? = nil
  ) -> TelemetryEventRaw {
    var body: [String: JSON] = ["view": .string(viewName)]
    body.merge(payload, uniquingKeysWith: { _, new in new })

    return TelemetryEventRaw(
      event: "VIEW_DID_APPEAR",
      payload: body,
      eventSamplingRate: samplingRate ?? viewDidAppearSamplingRate
    )
  }

}
