//
//  TelemetryCollectorTests.swift
//  Clerk
//

@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@Suite(.serialized)
struct TelemetryCollectorTests {
  private struct NetworkStub: NetworkRequester {
    func data(for _: URLRequest) async throws -> (Data, URLResponse) {
      (Data(), URLResponse())
    }
  }

  private final class RecordingNetwork: NetworkRequester {
    let requests = LockIsolated<[URLRequest]>([])

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      requests.withValue { $0.append(request) }
      return (Data(), URLResponse())
    }
  }

  private struct Environment: TelemetryEnvironmentProviding {
    let instanceType: String

    var sdkName: String {
      "clerk-ios"
    }

    var sdkVersion: String {
      "0.0.0"
    }

    func instanceTypeString() async -> String {
      instanceType
    }

    func isTelemetryEnabled() async -> Bool {
      true
    }

    func publishableKey() async -> String? {
      testPublishableKey
    }
  }

  private func makeCollector(instanceType: String) -> TelemetryCollector {
    TelemetryCollector(
      options: .init(disableThrottling: true),
      networkRequester: NetworkStub(),
      environment: Environment(instanceType: instanceType)
    )
  }

  @Test
  @MainActor
  func collectorIsReleasedAfterRecordingAnAcceptedEvent() async {
    configureClerkForTesting()
    weak var released: TelemetryCollector?

    do {
      let collector = makeCollector(instanceType: "development")
      released = collector
      await collector.record(TelemetryEventRaw(event: "TEST_EVENT", payload: [:]))
    }

    #expect(released == nil)
  }

  @Test
  @MainActor
  func collectorIsReleasedWhenEveryEventIsRejected() async {
    configureClerkForTesting()
    weak var released: TelemetryCollector?

    do {
      let collector = makeCollector(instanceType: "production")
      released = collector
      await collector.record(TelemetryEventRaw(event: "TEST_EVENT", payload: [:]))
    }

    #expect(released == nil)
  }

  @Test
  @MainActor
  func periodicFlushSendsAPartialBatch() async throws {
    configureClerkForTesting()
    let network = RecordingNetwork()
    let collector = TelemetryCollector(
      options: .init(flushInterval: 1, disableThrottling: true),
      networkRequester: network,
      environment: Environment(instanceType: "development")
    )

    await collector.record(TelemetryEventRaw(event: "TEST_EVENT", payload: [:]))

    let deadline = ContinuousClock.now + .seconds(5)
    while network.requests.value.isEmpty, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(50))
    }

    let body = try #require(network.requests.value.first?.httpBody)
    #expect(String(decoding: body, as: UTF8.self).contains("TEST_EVENT"))
    withExtendedLifetime(collector) {}
  }
}
