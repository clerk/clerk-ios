//
//  TelemetryTests.swift
//  Clerk
//
//  Created by Mike Pitre on 8/8/25.
//

import Foundation
import Testing

@testable import Clerk

/// Mock network requester that doesn't make real requests
struct MockNetworkRequester: NetworkRequester {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        // Return mock response without making actual network call
        let mockData = Data()
        let mockResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (mockData, mockResponse)
    }
}


// MARK: - Test Utilities for Decoupled Telemetry

/// Network requester that tracks call count and captures the last request body
actor CapturingNetworkRequester: NetworkRequester {
    private(set) var callCount = 0
    private(set) var lastRequestBody: Data?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        lastRequestBody = request.httpBody
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }
}

/// Mock environment provider to decouple tests from `Clerk`.
struct MockTelemetryEnvironment: TelemetryEnvironmentProviding {
    var sdkName: String = "clerk-ios"
    var sdkVersion: String = "1.0.0"
    var instanceType: String = "development"
    var telemetryEnabled: Bool = true
    var debugModeEnabled: Bool = false
    var pk: String? = nil

    func instanceTypeString() async -> String { instanceType }
    func isTelemetryEnabled() async -> Bool { telemetryEnabled }
    func isDebugModeEnabled() async -> Bool { debugModeEnabled }
    func publishableKey() async -> String? { pk }
}



@Suite("Telemetry System Tests")
struct TelemetryTests {
    
    // MARK: - TelemetryEvents Tests
    
    @Suite("Event Creation Tests")
    struct EventCreationTests {
        
        @Test("Method invoked event creation")
        func testMethodInvokedEvent() async throws {
            // Test with default sampling rate
            let event1 = TelemetryEvents.methodInvoked("signIn")
            
            #expect(event1.event == "METHOD_INVOKED")
            #expect(event1.payload["method"] == .string("signIn"))
            #expect(event1.eventSamplingRate == 0.1) // Default rate for method invoked
            
            // Test with additional payload
            let event2 = TelemetryEvents.methodInvoked(
                "signUp", 
                payload: ["userId": .string("user_123"), "orgId": .string("org_456")]
            )
            
            #expect(event2.event == "METHOD_INVOKED")
            #expect(event2.payload["method"] == .string("signUp"))
            #expect(event2.payload["userId"] == .string("user_123"))
            #expect(event2.payload["orgId"] == .string("org_456"))
            #expect(event2.eventSamplingRate == 0.1)
            
            // Test with custom sampling rate
            let event3 = TelemetryEvents.methodInvoked("criticalMethod", samplingRate: 0.5)
            
            #expect(event3.event == "METHOD_INVOKED")
            #expect(event3.payload["method"] == .string("criticalMethod"))
            #expect(event3.eventSamplingRate == 0.5)
        }
        
        @Test("View did appear event creation")
        func testViewDidAppearEvent() async throws {
            // Test with default sampling rate
            let event1 = TelemetryEvents.viewDidAppear("AuthView")
            
            #expect(event1.event == "VIEW_DID_APPEAR")
            #expect(event1.payload["view"] == .string("AuthView"))
            #expect(event1.eventSamplingRate == 0.2) // Default rate for view did appear
            
            // Test with additional payload
            let event2 = TelemetryEvents.viewDidAppear(
                "UserProfile",
                payload: ["mode": .string("edit"), "isDismissable": .bool(true)]
            )
            
            #expect(event2.event == "VIEW_DID_APPEAR")
            #expect(event2.payload["view"] == .string("UserProfile"))
            #expect(event2.payload["mode"] == .string("edit"))
            #expect(event2.payload["isDismissable"] == .bool(true))
            #expect(event2.eventSamplingRate == 0.2)
            
            // Test with custom sampling rate
            let event3 = TelemetryEvents.viewDidAppear("ErrorView", samplingRate: 1.0)
            
            #expect(event3.event == "VIEW_DID_APPEAR")
            #expect(event3.payload["view"] == .string("ErrorView"))
            #expect(event3.eventSamplingRate == 1.0)
        }
        
        @Test("Framework metadata event creation")
        func testFrameworkMetadataEvent() async throws {
            // Test basic metadata
            let metadata1: [String: JSON] = [
                "osVersion": .string("iOS 17.0"),
                "deviceModel": .string("iPhone15,2")
            ]
            let event1 = TelemetryEvents.frameworkMetadata(metadata1)
            
            #expect(event1.event == "FRAMEWORK_METADATA")
            #expect(event1.payload["osVersion"] == .string("iOS 17.0"))
            #expect(event1.payload["deviceModel"] == .string("iPhone15,2"))
            #expect(event1.eventSamplingRate == 1.0) // Default rate for framework metadata
            
            // Test with custom sampling rate
            let metadata2: [String: JSON] = [
                "debug": .string("info")
            ]
            let event2 = TelemetryEvents.frameworkMetadata(metadata2, samplingRate: 0.0)
            
            #expect(event2.event == "FRAMEWORK_METADATA")
            #expect(event2.payload["debug"] == .string("info"))
            #expect(event2.eventSamplingRate == 0.0)
        }
        
        @Test("Payload merging behavior")
        func testPayloadMerging() async throws {
            // Test that additional payload merges correctly and overwrites existing keys
            let event = TelemetryEvents.methodInvoked(
                "testMethod",
                payload: ["method": .string("overridden"), "extra": .string("data")]
            )
            
            #expect(event.event == "METHOD_INVOKED")
            #expect(event.payload["method"] == .string("overridden")) // Should be overridden
            #expect(event.payload["extra"] == .string("data"))
        }
        
        @Test("Default sampling rates")
        func testEventSamplingRates() async throws {
            // Verify default sampling rates for each event type
            let methodEvent = TelemetryEvents.methodInvoked("test")
            let viewEvent = TelemetryEvents.viewDidAppear("test")
            let metadataEvent = TelemetryEvents.frameworkMetadata([:])
            
            #expect(methodEvent.eventSamplingRate == 0.1)
            #expect(viewEvent.eventSamplingRate == 0.2)
            #expect(metadataEvent.eventSamplingRate == 1.0)
        }
        
        @Test("Custom sampling rate override")
        func testCustomSamplingRateOverride() async throws {
            // Test that custom sampling rates override defaults
            let customRate = 0.75
            
            let methodEvent = TelemetryEvents.methodInvoked("test", samplingRate: customRate)
            let viewEvent = TelemetryEvents.viewDidAppear("test", samplingRate: customRate)
            let metadataEvent = TelemetryEvents.frameworkMetadata([:], samplingRate: customRate)
            
            #expect(methodEvent.eventSamplingRate == customRate)
            #expect(viewEvent.eventSamplingRate == customRate)
            #expect(metadataEvent.eventSamplingRate == customRate)
        }
    }
    
    // MARK: - TelemetryThrottler Tests
    
    @Suite("Event Throttling Tests", .serialized)
    struct EventThrottlingTests {
        
        init() {
            // Clean up UserDefaults before each test to avoid interference
            UserDefaults.standard.removeObject(forKey: "clerk_telemetry_throttler")
        }
        
        @Test("Basic event throttling")
        func testEventThrottling() async throws {
            let throttler = TelemetryEventThrottler()
            
            // Create a test event
            let event = TelemetryEvent(
                event: "TEST_EVENT",
                it: "development",
                sdk: "clerk-ios",
                sdkv: "1.0.0",
                pk: "pk_test_123",
                payload: ["test": .string("data")]
            )
            
            // First call should not be throttled
            let isThrottled1 = await throttler.isEventThrottled(event)
            #expect(isThrottled1 == false)
            
            // Second call with same event should be throttled
            let isThrottled2 = await throttler.isEventThrottled(event)
            #expect(isThrottled2 == true)
            
            // Third call should still be throttled
            let isThrottled3 = await throttler.isEventThrottled(event)
            #expect(isThrottled3 == true)
            
            // Clean up
            UserDefaults.standard.removeObject(forKey: "clerk_telemetry_throttler")
        }
        
        @Test("Different events not throttled")
        func testDifferentEventsNotThrottled() async throws {
            let throttler = TelemetryEventThrottler()
            
            let event1 = TelemetryEvent(
                event: "EVENT_ONE",
                it: "development",
                sdk: "clerk-ios",
                sdkv: "1.0.0",
                pk: "pk_test_123",
                payload: ["test": .string("data1")]
            )
            
            let event2 = TelemetryEvent(
                event: "EVENT_TWO",
                it: "development",
                sdk: "clerk-ios", 
                sdkv: "1.0.0",
                pk: "pk_test_123",
                payload: ["test": .string("data2")]
            )
            
            // Both events should not be throttled initially
            let isThrottled1 = await throttler.isEventThrottled(event1)
            let isThrottled2 = await throttler.isEventThrottled(event2)
            
            #expect(isThrottled1 == false)
            #expect(isThrottled2 == false)
            
            // Second calls should be throttled independently
            let isThrottled1Second = await throttler.isEventThrottled(event1)
            let isThrottled2Second = await throttler.isEventThrottled(event2)
            
            #expect(isThrottled1Second == true)
            #expect(isThrottled2Second == true)
            
            // Clean up
            UserDefaults.standard.removeObject(forKey: "clerk_telemetry_throttler")
        }
        
        @Test("Same event with different payloads")
        func testSameEventWithDifferentPayloads() async throws {
            let throttler = TelemetryEventThrottler()
            
            let event1 = TelemetryEvent(
                event: "TEST_EVENT",
                it: "development",
                sdk: "clerk-ios",
                sdkv: "1.0.0",
                pk: "pk_test_123",
                payload: ["userId": .string("user1")]
            )
            
            let event2 = TelemetryEvent(
                event: "TEST_EVENT",
                it: "development", 
                sdk: "clerk-ios",
                sdkv: "1.0.0",
                pk: "pk_test_123",
                payload: ["userId": .string("user2")]
            )
            
            // Both events should not be throttled as they have different payloads
            let isThrottled1 = await throttler.isEventThrottled(event1)
            let isThrottled2 = await throttler.isEventThrottled(event2)
            
            #expect(isThrottled1 == false)
            #expect(isThrottled2 == false)
            
            // Repeating the same events should now be throttled
            let isThrottled1Second = await throttler.isEventThrottled(event1)
            let isThrottled2Second = await throttler.isEventThrottled(event2)
            
            #expect(isThrottled1Second == true)
            #expect(isThrottled2Second == true)
            
            // Clean up
            UserDefaults.standard.removeObject(forKey: "clerk_telemetry_throttler")
        }
        
        @Test("Key generation consistency")
        func testKeyGeneration() async throws {
            let throttler = TelemetryEventThrottler()
            
            let event1 = TelemetryEvent(
                event: "TEST_EVENT",
                it: "development",
                sdk: "clerk-ios",
                sdkv: "1.0.0",
                pk: "pk_test_123",
                payload: ["key": .string("value1")]
            )
            
            let event2 = TelemetryEvent(
                event: "TEST_EVENT",
                it: "development",
                sdk: "clerk-ios", 
                sdkv: "1.0.0",
                pk: "pk_test_123",
                payload: ["key": .string("value2")]
            )
            
            // Generate keys for both events
            let key1 = await throttler.generateKey(for: event1)
            let key2 = await throttler.generateKey(for: event2)
            
            // Keys should be different due to different payloads
            #expect(key1 != key2)
            
            // Same event should generate same key
            let key1Duplicate = await throttler.generateKey(for: event1)
            #expect(key1 == key1Duplicate)
        }
        
        @Test("Cache expiry behavior")
        func testCacheExpiry() async throws {
            let throttler = TelemetryEventThrottler()
            
            let event = TelemetryEvent(
                event: "TEST_EVENT",
                it: "development",
                sdk: "clerk-ios",
                sdkv: "1.0.0", 
                pk: "pk_test_123",
                payload: ["test": .string("data")]
            )
            
            // Manually manipulate UserDefaults to test cache expiry
            let key = await throttler.generateKey(for: event)
            let storageKey = "clerk_telemetry_throttler"
            
            // Set an expired entry (timestamp from 25 hours ago)
            let expiredTimestamp = Date().timeIntervalSince1970 * 1000 - (25 * 60 * 60 * 1000)
            let expiredCache = [key: expiredTimestamp]
            // Encode the cache the same way the throttler does
            if let data = try? JSONEncoder().encode(expiredCache) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
            
            // Should not be throttled since the cache entry is expired
            let isThrottled = await throttler.isEventThrottled(event)
            #expect(isThrottled == false)
            
            // Clean up
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
        
        @Test("Cache behavior with mixed entries")
        func testCacheBehaviorWithMixedEntries() async throws {
            let throttler = TelemetryEventThrottler()
            let storageKey = "clerk_telemetry_throttler"
            
            // Set up a mix of expired and valid entries
            let now = Date().timeIntervalSince1970 * 1000
            let expiredTimestamp = now - (25 * 60 * 60 * 1000) // 25 hours ago
            let validTimestamp = now - (1 * 60 * 60 * 1000)   // 1 hour ago
            
            let mixedCache = [
                "expired_key1": expiredTimestamp,
                "expired_key2": expiredTimestamp,
                "valid_key1": validTimestamp,
                "valid_key2": validTimestamp
            ]
            
            // Encode the cache the same way the throttler does
            if let data = try? JSONEncoder().encode(mixedCache) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
            
            // Create a dummy event to trigger cache interaction
            let event = TelemetryEvent(
                event: "TEST_EVENT",
                it: "development",
                sdk: "clerk-ios",
                sdkv: "1.0.0",
                pk: "pk_test_123",
                payload: ["test": .string("data")]
            )
            
            // This should add a new entry since it's a different event
            let isThrottled = await throttler.isEventThrottled(event)
            #expect(isThrottled == false) // New event should not be throttled
            
            // The throttler doesn't bulk cleanup - it only handles entries as they're accessed
            // So the expired entries will still be there until they're individually checked
            
            // Clean up
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
        
        @Test("Multiple throttler instances share storage")
        func testMultipleThrottlers() async throws {
            // Test that multiple throttler instances share the same storage
            let throttler1 = TelemetryEventThrottler()
            let throttler2 = TelemetryEventThrottler()
            
            let event = TelemetryEvent(
                event: "TEST_EVENT",
                it: "development",
                sdk: "clerk-ios",
                sdkv: "1.0.0",
                pk: "pk_test_123",
                payload: ["test": .string("data")]
            )
            
            // First throttler records the event
            let isThrottled1 = await throttler1.isEventThrottled(event)
            #expect(isThrottled1 == false)
            
            // Second throttler should see it as throttled
            let isThrottled2 = await throttler2.isEventThrottled(event)
            #expect(isThrottled2 == true)
            
            // Clean up
            UserDefaults.standard.removeObject(forKey: "clerk_telemetry_throttler")
        }
    }
    
    // MARK: - TelemetryTypes Tests
    
    @Suite("Data Structure Tests")
    struct DataStructureTests {
        
        @Test("TelemetryCollectorOptions initialization")
        func testTelemetryCollectorOptions() async throws {
            // Test default values
            let defaultOptions = TelemetryCollectorOptions()
            #expect(defaultOptions.samplingRate == 1.0)
            #expect(defaultOptions.maxBufferSize == 5)
            #expect(defaultOptions.disableThrottling == false)
            
            // Test custom values
            let customOptions = TelemetryCollectorOptions(
                samplingRate: 0.5,
                maxBufferSize: 10,
                disableThrottling: true
            )
            #expect(customOptions.samplingRate == 0.5)
            #expect(customOptions.maxBufferSize == 10)
            #expect(customOptions.disableThrottling == true)
            
            // Test buffer size validation (minimum 1)
            let invalidOptions = TelemetryCollectorOptions(maxBufferSize: 0)
            #expect(invalidOptions.maxBufferSize == 1)
        }
        
        @Test("TelemetryEvent encoding and decoding")
        func testTelemetryEventCodable() async throws {
            let event = TelemetryEvent(
                event: "TEST_EVENT",
                it: "development",
                sdk: "clerk-ios",
                sdkv: "1.0.0",
                pk: "pk_test_123",
                payload: [
                    "string": .string("value"),
                    "number": .number(42),
                    "bool": .bool(true),
                    "null": .null
                ]
            )
            
            // Test encoding
            let encoder = JSONEncoder()
            let data = try encoder.encode(event)
            #expect(data.count > 0)
            
            // Test decoding
            let decoder = JSONDecoder()
            let decodedEvent = try decoder.decode(TelemetryEvent.self, from: data)
            
            #expect(decodedEvent.event == event.event)
            #expect(decodedEvent.it == event.it)
            #expect(decodedEvent.sdk == event.sdk)
            #expect(decodedEvent.sdkv == event.sdkv)
            #expect(decodedEvent.pk == event.pk)
            #expect(decodedEvent.payload["string"] == .string("value"))
            #expect(decodedEvent.payload["number"] == .number(42))
            #expect(decodedEvent.payload["bool"] == .bool(true))
            #expect(decodedEvent.payload["null"] == .null)
        }

        
        @Test("TelemetryEventRaw initialization")
        func testTelemetryEventRaw() async throws {
            // Test with default sampling rate
            let rawEvent1 = TelemetryEventRaw(
                event: "TEST_EVENT",
                payload: ["key": .string("value")]
            )
            #expect(rawEvent1.event == "TEST_EVENT")
            #expect(rawEvent1.payload["key"] == .string("value"))
            #expect(rawEvent1.eventSamplingRate == nil)
            
            // Test with custom sampling rate
            let rawEvent2 = TelemetryEventRaw(
                event: "TEST_EVENT",
                payload: ["key": .string("value")],
                eventSamplingRate: 0.5
            )
            #expect(rawEvent2.event == "TEST_EVENT")
            #expect(rawEvent2.payload["key"] == .string("value"))
            #expect(rawEvent2.eventSamplingRate == 0.5)
        }
    }
    
    // MARK: - TelemetryCollector Tests
    
    @Suite("Telemetry Collection Tests", .serialized)
    struct TelemetryCollectionTests {
        
        init() {
            // Clean up any existing UserDefaults before each test
            UserDefaults.standard.removeObject(forKey: "clerk_telemetry_throttler")
        }
        
        @Test("Collector initialization")
        func testCollectorInitialization() async throws {
            let options = TelemetryCollectorOptions(samplingRate: 0.8, maxBufferSize: 3)
            let _ = TelemetryCollector(options: options, networkRequester: MockNetworkRequester())
            
            // Test that collector is properly initialized (no crash)
            #expect(Bool(true)) // If we reach here, initialization succeeded
        }
        
        @Test("Event recording with global sampling")
        func testEventRecordingWithSampling() async throws {
            // Use 0% sampling to ensure events are never recorded
            let options = TelemetryCollectorOptions(samplingRate: 0.0, maxBufferSize: 10)
            let collector = TelemetryCollector(options: options, networkRequester: MockNetworkRequester(), environment: MockTelemetryEnvironment())
            
            let rawEvent = TelemetryEventRaw(
                event: "TEST_EVENT",
                payload: ["test": .string("data")],
                eventSamplingRate: 0.0 // Also 0% for the specific event
            )
            
            await collector.record(rawEvent)
            // With 0% sampling, no network requests should be made
        }
        
        @Test("Event recording with per-event sampling override")
        func testEventRecordingWithPerEventSampling() async throws {
            // Use 0% global sampling but override with 100% for specific event
            let options = TelemetryCollectorOptions(samplingRate: 0.0, maxBufferSize: 1)
            let collector = TelemetryCollector(options: options, networkRequester: MockNetworkRequester(), environment: MockTelemetryEnvironment())
            
            let rawEvent = TelemetryEventRaw(
                event: "TEST_EVENT",
                payload: ["test": .string("data")],
                eventSamplingRate: 1.0 // 100% sampling for this event
            )
            
            await collector.record(rawEvent)
            // This should bypass global sampling due to per-event override
        }
        
        @Test("Buffer size management")
        func testBufferSizeManagement() async throws {
            let options = TelemetryCollectorOptions(samplingRate: 1.0, maxBufferSize: 2)
            let collector = TelemetryCollector(options: options, networkRequester: MockNetworkRequester(), environment: MockTelemetryEnvironment())
            
            // Record events up to buffer size - should automatically flush
            let event1 = TelemetryEventRaw(event: "TEST_1", payload: [:], eventSamplingRate: 1.0)
            let event2 = TelemetryEventRaw(event: "TEST_2", payload: [:], eventSamplingRate: 1.0)
            
            await collector.record(event1)
            await collector.record(event2) // Should trigger flush when buffer is full
        }
        
        @Test("Manual flush functionality")
        func testManualFlush() async throws {
            let collector = TelemetryCollector(options: .init(), networkRequester: MockNetworkRequester(), environment: MockTelemetryEnvironment())
            
            // Test that manual flush doesn't crash
            await collector.flush()
        }
        
        @Test("Event throttling integration")
        func testEventThrottlingIntegration() async throws {
            let collector = TelemetryCollector(options: .init(), networkRequester: MockNetworkRequester(), environment: MockTelemetryEnvironment())
            
            let rawEvent = TelemetryEventRaw(
                event: "REPEATED_EVENT",
                payload: ["test": .string("data")],
                eventSamplingRate: 1.0
            )
            
            // First event should not be throttled
            await collector.record(rawEvent)
            
            // Second identical event should be throttled
            await collector.record(rawEvent)
        }
        
        @Test("Disable throttling functionality") 
        func testDisableThrottling() async throws {
            // Test with all filtering disabled (should record ALL events)
            let noFilteringOptions = TelemetryCollectorOptions(
                samplingRate: 0.0, // 0% sampling rate (should be bypassed)
                maxBufferSize: 10,
                disableThrottling: true
            )
            let noFilteringCollector = TelemetryCollector(options: noFilteringOptions, environment: MockTelemetryEnvironment())
            
            // Test with normal filtering
            let normalOptions = TelemetryCollectorOptions(
                samplingRate: 0.0, // 0% sampling rate
                maxBufferSize: 10,
                disableThrottling: false
            )
            let normalCollector = TelemetryCollector(options: normalOptions, environment: MockTelemetryEnvironment())
            
            let rawEvent = TelemetryEventRaw(
                event: "TEST_EVENT",
                payload: ["test": .string("data")],
                eventSamplingRate: 0.0 // 0% sampling (should be bypassed when filtering disabled)
            )
            
            // With filtering disabled, ALL events should be recorded despite 0% sampling
            await noFilteringCollector.record(rawEvent)
            await noFilteringCollector.record(rawEvent) // Duplicate should also work
            await noFilteringCollector.record(rawEvent) // Another duplicate should work
            
            // With normal filtering, events should be dropped due to 0% sampling
            await normalCollector.record(rawEvent)
            await normalCollector.record(rawEvent)
        }
    }
    
    // MARK: - Integration Tests
    
    @Suite("Integration Tests", .serialized)
    struct IntegrationTests {
        
        init() {
            UserDefaults.standard.removeObject(forKey: "clerk_telemetry_throttler")
        }
        
        @Test("End-to-end telemetry flow")
        @MainActor
        func testEndToEndTelemetryFlow() async throws {
            // Configure a test Clerk instance
            let clerk = Clerk()
            clerk.configure(publishableKey: "pk_test_123456789")
            
            // Test that telemetry collector is available (no crash accessing it)
            let _ = clerk.telemetry // If we reach here, telemetry is available
            
            // Record various types of events
            await clerk.telemetry.record(TelemetryEvents.methodInvoked("signIn"))
            await clerk.telemetry.record(TelemetryEvents.viewDidAppear("AuthView"))
            await clerk.telemetry.record(TelemetryEvents.frameworkMetadata(["os": .string("iOS")]))
            
            // Manual flush to ensure all events are processed
            await clerk.telemetry.flush()
        }
        
        @Test("Telemetry with different instance types")
        @MainActor
        func testTelemetryWithInstanceTypes() async throws {
            // Test with development instance
            let devClerk = Clerk()
            devClerk.configure(publishableKey: "pk_test_123456789")
            #expect(devClerk.instanceType == .development)
            
            await devClerk.telemetry.record(TelemetryEvents.methodInvoked("testMethod"))
            
            // Test with production instance
            let prodClerk = Clerk()
            prodClerk.configure(publishableKey: "pk_live_123456789")
            #expect(prodClerk.instanceType == .production)
            
            await prodClerk.telemetry.record(TelemetryEvents.methodInvoked("testMethod"))
        }
        
        @Test("Event helpers produce valid events")
        func testEventHelpersProduceValidEvents() async throws {
            // Test that all event helpers produce events that can be processed
            let collector = TelemetryCollector(options: .init(), networkRequester: MockNetworkRequester(), environment: MockTelemetryEnvironment())
            
            let methodEvent = TelemetryEvents.methodInvoked("testMethod", payload: ["userId": .string("123")])
            let viewEvent = TelemetryEvents.viewDidAppear("TestView", payload: ["mode": .string("test")])
            let metadataEvent = TelemetryEvents.frameworkMetadata(["version": .string("1.0")])
            
            // All events should be recordable without errors
            await collector.record(methodEvent)
            await collector.record(viewEvent)
            await collector.record(metadataEvent)
        }
        
        @Test("Telemetry collector options configuration")
        func testTelemetryCollectorOptionsConfiguration() async throws {
            // Test custom options
            let customOptions = TelemetryCollectorOptions(
                samplingRate: 0.5,
                maxBufferSize: 20,
                flushInterval: 60.0,
                disableThrottling: true
            )
            
            #expect(customOptions.samplingRate == 0.5)
            #expect(customOptions.maxBufferSize == 20)
            #expect(customOptions.flushInterval == 60.0)
            #expect(customOptions.disableThrottling == true)
            
            // Test default options
            let defaultOptions = TelemetryCollectorOptions()
            #expect(defaultOptions.samplingRate == 1.0)
            #expect(defaultOptions.maxBufferSize == 5)
            #expect(defaultOptions.flushInterval == 30.0)
            #expect(defaultOptions.disableThrottling == false)
            
            // Test collector initialization
            let collector = TelemetryCollector(options: customOptions, networkRequester: MockNetworkRequester(), environment: MockTelemetryEnvironment())
            let _ = collector // Should create successfully
        }
        
        @Test("Flush interval validation")
        func testFlushIntervalValidation() async throws {
            // Test minimum flush interval is enforced
            let options = TelemetryCollectorOptions(flushInterval: 0.5)
            #expect(options.flushInterval == 1.0) // Should be clamped to minimum of 1.0
            
            let negativeOptions = TelemetryCollectorOptions(flushInterval: -5.0)
            #expect(negativeOptions.flushInterval == 1.0) // Should be clamped to minimum of 1.0
        }
        
        
        @Test("Periodic flush timing configuration")
        func testPeriodicFlushConfiguration() async throws {
            // Test flush interval configuration
            let quickOptions = TelemetryCollectorOptions(flushInterval: 5.0)
            let slowOptions = TelemetryCollectorOptions(flushInterval: 120.0)
            
            #expect(quickOptions.flushInterval == 5.0)
            #expect(slowOptions.flushInterval == 120.0)
            
            // Test that collectors can be created with different intervals
            let _ = TelemetryCollector(options: quickOptions, networkRequester: MockNetworkRequester(), environment: MockTelemetryEnvironment())
            let _ = TelemetryCollector(options: slowOptions, networkRequester: MockNetworkRequester(), environment: MockTelemetryEnvironment())
        }
    }
}
