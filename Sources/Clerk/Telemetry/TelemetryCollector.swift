//
//  TelemetryCollector.swift
//  Clerk
//
//  Created by AI Assistant on 2025-08-08.
//

import Foundation

/// A development-only telemetry collector for the Clerk iOS SDK.
///
/// The collector is automatically disabled in production instances.
actor TelemetryCollector {
    // MARK: Types

    private struct Config: Sendable {
        var samplingRate: Double
        var maxBufferSize: Int
        var endpoint: URL
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

    // MARK: Init

    /// Creates a new telemetry collector.
    ///
    /// - Parameter options: Configuration options controlling sampling, buffering and metadata.
    init(options: TelemetryCollectorOptions) {
        self.config = Config(
            samplingRate: options.samplingRate,
            maxBufferSize: options.maxBufferSize,
            endpoint: Self.defaultEndpoint
        )

        let sdkName = "clerk-ios"
        let sdkVersion = Clerk.version

        self.metadata = Metadata(
            sdk: sdkName,
            sdkVersion: sdkVersion
        )
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
        let randomSeed = Double.random(in: 0...1)
        let globalOk = randomSeed <= config.samplingRate
        let eventOk = eventSamplingRate.map { randomSeed <= $0 } ?? true
        guard globalOk && eventOk else { return false }
        return !(await throttler.isEventThrottled(prepared))
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
            return
        }

        // If a flush is already scheduled, do nothing
        if flushTask != nil { return }

        // Schedule a background flush on the next tick
        flushTask = Task { [weak self] in
            guard let self else { return }
            await Task.yield()
            await self.flush()
        }
    }

    /// Flush buffered events to the telemetry endpoint.
    private func flush() async {
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
            let _ = try await URLSession.shared.data(for: request)
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

private extension TelemetryCollector { }


