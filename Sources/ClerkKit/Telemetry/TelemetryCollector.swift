//
//  TelemetryCollector.swift
//  Clerk
//

import Foundation

/// Protocol for making network requests - allows for easy testing
protocol NetworkRequester: Sendable {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkRequester {}

package protocol TelemetryCollectorProtocol: Sendable {
  func record(_ raw: TelemetryEventRaw) async

  func flush() async
}

package actor NoOpTelemetryCollector: TelemetryCollectorProtocol {
  package func record(_: TelemetryEventRaw) async {}

  package func flush() async {}
}

/// A development-only telemetry collector for the Clerk iOS SDK.
///
/// The collector is automatically disabled in production instances.
package actor TelemetryCollector: TelemetryCollectorProtocol {
  // MARK: Types

  private struct RecordResult {
    let shouldRecord: Bool
    let reason: String
  }

  private struct Config {
    var samplingRate: Double
    var maxBufferSize: Int
    var endpoint: URL
    var disableThrottling: Bool
    var networkRequester: NetworkRequester
    var flushInterval: TimeInterval
  }

  private struct Metadata {
    var sdk: String
    var sdkVersion: String
  }

  // MARK: Constants

  private static let defaultEndpoint = URL(string: "https://clerk-telemetry.com")!

  // MARK: State

  private var config: Config
  private var throttler = TelemetryEventThrottler()
  private var metadata: Metadata
  private var buffer: [TelemetryEvent] = []
  private var flushTask: Task<Void, Never>?
  private var flushTimer: Task<Void, Never>?
  private let environment: TelemetryEnvironmentProviding
  private var isPeriodicFlushingStarted = false

  // MARK: Init

  init(
    options: TelemetryCollectorOptions = .init(),
    networkRequester: NetworkRequester = URLSession.shared,
    environment: TelemetryEnvironmentProviding = ClerkTelemetryEnvironment()
  ) {
    config = Config(
      samplingRate: options.samplingRate,
      maxBufferSize: options.maxBufferSize,
      endpoint: Self.defaultEndpoint,
      disableThrottling: options.disableThrottling,
      networkRequester: networkRequester,
      flushInterval: options.flushInterval
    )
    self.environment = environment

    metadata = Metadata(
      sdk: environment.sdkName,
      sdkVersion: environment.sdkVersion
    )
  }

  deinit {
    flushTimer?.cancel()
    flushTask?.cancel()
  }

  package func record(_ raw: TelemetryEventRaw) async {
    let prepared = await preparePayload(event: raw.event, payload: raw.payload)
    let recordResult = await shouldRecord(prepared, eventSamplingRate: raw.eventSamplingRate)

    if recordResult.shouldRecord {
      await logEventIfDebug(name: prepared.event, prepared)
    } else {
      await logEventIfDebug(name: "[skipped - \(recordResult.reason)] \(prepared.event)", prepared)
    }

    if !recordResult.shouldRecord { return }

    if !isPeriodicFlushingStarted {
      isPeriodicFlushingStarted = true
      startPeriodicFlushing()
    }

    buffer.append(prepared)
    await scheduleFlushIfNeeded()
  }

  // MARK: Private helpers

  private func shouldRecord(_ prepared: TelemetryEvent, eventSamplingRate: Double?) async -> RecordResult {
    guard await environment.isTelemetryEnabled() else {
      return RecordResult(shouldRecord: false, reason: "telemetry disabled")
    }
    guard await environment.instanceTypeString() == "development" else {
      return RecordResult(shouldRecord: false, reason: "production instance")
    }

    let samplingResult = await shouldBeSampled(prepared, eventSamplingRate: eventSamplingRate)
    return RecordResult(shouldRecord: samplingResult.shouldRecord, reason: samplingResult.reason)
  }

  private func shouldBeSampled(_ prepared: TelemetryEvent, eventSamplingRate: Double?) async -> RecordResult {
    if config.disableThrottling {
      return RecordResult(shouldRecord: true, reason: "throttling disabled")
    }

    let randomSeed = Double.random(in: 0 ... 1)
    let globalOk = randomSeed <= config.samplingRate
    let eventOk = eventSamplingRate.map { randomSeed <= $0 } ?? true

    if !globalOk {
      return RecordResult(shouldRecord: false, reason: "global sampling (\(Int(config.samplingRate * 100))%)")
    }

    if !eventOk, let eventRate = eventSamplingRate {
      return RecordResult(shouldRecord: false, reason: "event sampling (\(Int(eventRate * 100))%)")
    }

    let isThrottled = await throttler.isEventThrottled(prepared)
    if isThrottled {
      return RecordResult(shouldRecord: false, reason: "throttled")
    }

    return RecordResult(shouldRecord: true, reason: "accepted")
  }

  private func startPeriodicFlushing() {
    let flushInterval = config.flushInterval
    flushTimer = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(flushInterval))

        // Rebind per tick so a sleeping loop doesn't keep a replaced collector alive.
        guard let self else { return }

        let hasEvents = await hasBufferedEvents()
        if hasEvents {
          await flush()
        }
      }
    }
  }

  private func hasBufferedEvents() -> Bool {
    !buffer.isEmpty
  }

  private func scheduleFlushIfNeeded() async {
    let isBufferFull = buffer.count >= config.maxBufferSize
    if isBufferFull {
      flushTask?.cancel()
      flushTask = Task { [weak self] in
        guard let self else { return }
        await flush()
      }
    }
  }

  package func flush() async {
    let eventsToSend = buffer
    buffer.removeAll(keepingCapacity: true)

    guard !eventsToSend.isEmpty else { return }

    let body = ["events": eventsToSend]
    guard let requestBody = try? JSONEncoder().encode(body) else { return }

    var request = URLRequest(url: config.endpoint.appendingPathComponent("v1/event"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = requestBody

    do {
      _ = try await config.networkRequester.data(for: request)
    } catch {
      let shouldLog = await Task { @MainActor in
        let configuredLevel = Clerk.shared.options.logLevel
        return configuredLevel <= .debug
      }.value

      if shouldLog {
        ClerkLogger.logNetworkError(
          error,
          endpoint: request.url?.absoluteString ?? "telemetry"
        )
      }
    }

    flushTask = nil
  }

  private func logEventIfDebug(name: String, _ payload: Any) async {
    let shouldLog = await Task { @MainActor in
      let configuredLevel = Clerk.shared.options.logLevel
      return configuredLevel <= .debug
    }.value

    guard shouldLog else { return }
    ClerkLogger.debug("[telemetry] \(name): \(payload)")
  }

  private func preparePayload(event: String, payload: [String: JSON]) async -> TelemetryEvent {
    let instanceTypeString = await environment.instanceTypeString()
    let publishableKey = await environment.publishableKey()
    return TelemetryEvent(
      event: event,
      it: instanceTypeString,
      sdk: metadata.sdk,
      sdkv: metadata.sdkVersion,
      pk: publishableKey,
      payload: payload
    )
  }

  // MARK: - Testing hooks

  func debugBufferedEvents() async -> [TelemetryEvent] {
    buffer
  }

  func debugResetBuffer() async {
    buffer.removeAll(keepingCapacity: true)
  }
}
