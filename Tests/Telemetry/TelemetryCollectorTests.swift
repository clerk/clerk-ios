//
//  TelemetryCollectorTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct TelemetryCollectorTests {
  private struct NetworkStub: NetworkRequester {
    func data(for _: URLRequest) async throws -> (Data, URLResponse) {
      (Data(), URLResponse())
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
}
