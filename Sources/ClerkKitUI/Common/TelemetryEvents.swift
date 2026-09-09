import ClerkKit

@MainActor
enum TelemetryEvents {
  static func viewDidAppear(
    _ viewName: String,
    payload: [String: JSONValue] = [:],
    samplingRate: Double = 0.1
  ) -> TelemetryEventRawRecord {
    var body: [String: JSONValue] = ["view": .string(viewName)]
    body.merge(payload, uniquingKeysWith: { _, new in new })
    return .init(event: "VIEW_DID_APPEAR", eventSamplingRate: samplingRate, payload: body)
  }
}
