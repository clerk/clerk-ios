//
//  TelemetryCollector.swift
//  Clerk
//
//  Created by AI Assistant on 2025-08-08.
//

import Foundation

/// Protocol for making network requests - allows for easy testing
protocol NetworkRequester: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkRequester {
    // URLSession already conforms to this signature
}

/// A development-only telemetry collector for the Clerk iOS SDK.
///
/// The collector is automatically disabled in production instances.
actor TelemetryCollector {
    // MARK: Types

    private struct Config: Sendable {
        var samplingRate: Double
        var maxBufferSize: Int
        var endpoint: URL
        var disableThrottling: Bool
        var networkRequester: NetworkRequester
        var flushInterval: TimeInterval
    }

    private struct Metadata: Sendable {
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
    private var flushTask: Task<Void, Never>? = nil
    private var flushTimer: Task<Void, Never>? = nil

    // MARK: Init

    /// Creates a new telemetry collector.
    ///
    /// - Parameters:
    ///   - options: Configuration options controlling sampling, buffering and metadata.
    ///   - networkRequester: Network requester for making HTTP requests. Defaults to URLSession.shared.
    init(options: TelemetryCollectorOptions = .init(), networkRequester: NetworkRequester = URLSession.shared) {
        self.config = Config(
            samplingRate: options.samplingRate,
            maxBufferSize: options.maxBufferSize,
            endpoint: Self.defaultEndpoint,
            disableThrottling: options.disableThrottling,
            networkRequester: networkRequester,
            flushInterval: options.flushInterval
        )

        let sdkName = "clerk-ios"
        let sdkVersion = Clerk.version

        self.metadata = Metadata(
            sdk: sdkName,
            sdkVersion: sdkVersion
        )
        
        // Start periodic flushing
        Task { await startPeriodicFlush() }
    }
    
    deinit {
        flushTimer?.cancel()
        flushTask?.cancel()
    }

    /// Record an event to be sampled, throttled, buffered and sent.
    ///
    /// - Parameter raw: The raw event description to record.
    func record(_ raw: TelemetryEventRaw) async {
        let prepared = await preparePayload(event: raw.event, payload: raw.payload)
        let shouldRecordResult = await shouldRecord(prepared, eventSamplingRate: raw.eventSamplingRate)
        // Log exactly once in debug: either as normal or as [skipped]
        await logEventIfDebug(name: shouldRecordResult ? prepared.event : "[skipped] \(prepared.event)", prepared)
        if !shouldRecordResult { return }
        buffer.append(prepared)
        await scheduleFlushIfNeeded()
    }

    // MARK: Private helpers

    private func shouldRecord(_ prepared: TelemetryEvent, eventSamplingRate: Double?) async -> Bool {
        guard await isTelemetryEnabled() else { return false }
        guard await isDevelopmentInstance() else { return false }
        return await shouldBeSampled(prepared, eventSamplingRate: eventSamplingRate)
    }

    private func shouldBeSampled(_ prepared: TelemetryEvent, eventSamplingRate: Double?) async -> Bool {
        // When throttling is disabled, record all events (bypass sampling and throttling)
        if config.disableThrottling {
            return true
        }
        
        let randomSeed = Double.random(in: 0...1)
        let globalOk = randomSeed <= config.samplingRate
        let eventOk = eventSamplingRate.map { randomSeed <= $0 } ?? true
        guard globalOk && eventOk else { return false }
        
        return !(await throttler.isEventThrottled(prepared))
    }

    /// Starts a periodic timer to flush events at regular intervals
    private func startPeriodicFlush() {
        flushTimer = Task { [weak self] in
            guard let self else { return }
            
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(config.flushInterval))
                
                let hasEvents = await self.hasBufferedEvents()
                if hasEvents {
                    await self.flush()
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
            // Cancel any pending flush and schedule an immediate background flush
            flushTask?.cancel()
            flushTask = Task { [weak self] in
                guard let self else { return }
                await self.flush()
            }
        }
        // Note: Only flush when buffer is full, not on every event
        // This allows proper batching of events
    }

    /// Flush buffered events to the telemetry endpoint.
    func flush() async {
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
            let _ = try await config.networkRequester.data(for: request)
        } catch {
            if await isDebugModeEnabled() {
                ClerkLogger.logNetworkError(
                    error,
                    endpoint: request.url?.absoluteString ?? "telemetry"
                )
            }
        }

        flushTask = nil
    }

    private func logEventIfDebug(name: String, _ payload: Any) async {
        guard await isDebugModeEnabled() else { return }
        ClerkLogger.debug("[telemetry] \(name): \(payload)", debugMode: true)
    }

    /// Enrich the raw event with SDK metadata and instance information.
    private func preparePayload(event: String, payload: [String: JSON]) async -> TelemetryEvent {
        let instanceTypeString = await instanceTypeString()
        let publishableKey = await MainActor.run { Clerk.shared.publishableKey }
        return TelemetryEvent(
            event: event,
            it: instanceTypeString,
            sdk: metadata.sdk,
            sdkv: metadata.sdkVersion,
            pk: publishableKey.isEmpty ? nil : publishableKey,
            payload: payload
        )
    }

    private func isDevelopmentInstance() async -> Bool {
        await MainActor.run { Clerk.shared.instanceType == .development }
    }

    private func instanceTypeString() async -> String {
        await MainActor.run { Clerk.shared.instanceType.rawValue }
    }

    private func isTelemetryEnabled() async -> Bool {
        await MainActor.run { Clerk.shared.settings.telemetryEnabled }
    }

    private func isDebugModeEnabled() async -> Bool {
        await MainActor.run { Clerk.shared.settings.debugMode }
    }
}
