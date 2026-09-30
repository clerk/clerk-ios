//
//  ClerkLoggerTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkLoggerTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func info_WithDefaultForce_RespectsLogLevel() async throws {
    Clerk.configure(publishableKey: testPublishableKey, options: Clerk.Options(logLevel: .error))
    let lines = captureLogLines()
    defer { restoreLogSink() }

    ClerkLogger.info("default-force info")
    ClerkLogger.logNetworkError(URLError(.badURL), endpoint: "sentinel")

    _ = try await waitForLine(containing: "sentinel", in: lines)
    #expect(!lines.value.contains { $0.text.contains("default-force info") })
  }

  @Test
  func info_WithForceTrue_AlwaysLogs() async throws {
    Clerk.configure(publishableKey: testPublishableKey, options: Clerk.Options(logLevel: .error))
    let lines = captureLogLines()
    defer { restoreLogSink() }

    ClerkLogger.info("forced info", force: true)

    let line = try await waitForLine(containing: "forced info", in: lines)
    #expect(line.level == .info)
    #expect(line.text.contains("[INFO]"))
    #expect(line.text.hasSuffix("- 🚨 forced info"))
  }

  @Test
  func info_WithForceFalse_RespectsLogLevel() async throws {
    Clerk.configure(publishableKey: testPublishableKey, options: Clerk.Options(logLevel: .error))
    let lines = captureLogLines()
    defer { restoreLogSink() }

    ClerkLogger.info("unforced info", force: false)
    ClerkLogger.logNetworkError(URLError(.badURL), endpoint: "sentinel")

    _ = try await waitForLine(containing: "sentinel", in: lines)
    #expect(!lines.value.contains { $0.text.contains("unforced info") })
  }

  @Test
  func info_WithInfoLogLevel_LogsWithoutForce() async throws {
    Clerk.configure(publishableKey: testPublishableKey, options: Clerk.Options(logLevel: .info))
    let lines = captureLogLines()
    defer { restoreLogSink() }

    ClerkLogger.info("info at info level")

    let line = try await waitForLine(containing: "info at info level", in: lines)
    #expect(line.level == .info)
    #expect(line.text.hasSuffix("- info at info level"))
    #expect(!line.text.contains("🚨"))
  }

  @Test
  func info_WithForceTrue_DoesNotTriggerErrorCallback() async throws {
    let entries = LockIsolated<[LogEntry]>([])
    let options = Clerk.Options(
      logLevel: .error,
      loggerHandler: { entry in
        entries.withValue { $0.append(entry) }
      }
    )
    Clerk.configure(publishableKey: testPublishableKey, options: options)
    let lines = captureLogLines()
    defer { restoreLogSink() }

    ClerkLogger.info("forced info", force: true)
    _ = try await waitForLine(containing: "forced info", in: lines)
    ClerkLogger.error("sentinel error")

    let deadline = ContinuousClock.now + .seconds(1)
    while !entries.value.contains(where: { $0.message == "sentinel error" }), ContinuousClock.now < deadline {
      await Task.yield()
    }
    #expect(entries.value.map(\.message) == ["sentinel error"])
  }

  @Test
  func error_AlwaysLogsRegardlessOfLogLevel() async throws {
    Clerk.configure(publishableKey: testPublishableKey, options: Clerk.Options(logLevel: .error))
    let lines = captureLogLines()
    defer { restoreLogSink() }

    ClerkLogger.error("error message", error: URLError(.badURL))

    let line = try await waitForLine(containing: "error message", in: lines)
    #expect(line.level == .error)
    #expect(line.text.contains("[ERROR]"))
    #expect(line.text.contains("- 🚨 error message\n   Error: "))
  }

  @Test
  func preInstallationCleanupUsesItsExplicitLoggerOptions() async throws {
    await Clerk.resetSharedInstanceForTesting()
    defer { configureClerkForTesting() }

    let entries = LockIsolated<[LogEntry]>([])
    let options = Clerk.Options(
      loggerHandler: { entry in
        entries.withValue { $0.append(entry) }
      }
    )
    let keychain = PreInstallationDeleteFailingKeychain()
    let clerk = Clerk()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: options
    )

    #expect(throws: ClerkClientError.self) {
      try Clerk.clearLocalClerkStorageStrictly(in: dependencies)
    }

    let deadline = ContinuousClock.now + .seconds(1)
    while !entries.value.contains(where: {
      $0.message.contains("Failed to delete keychain item")
    }), ContinuousClock.now < deadline {
      await Task.yield()
    }
    let keychainEntry = try #require(entries.value.first {
      $0.message.contains("Failed to delete keychain item")
    })
    #expect(keychainEntry.level == .error)
  }
}

private struct EmittedLogLine {
  let level: LogLevel
  let text: String
}

@MainActor
private func captureLogLines() -> LockIsolated<[EmittedLogLine]> {
  let lines = LockIsolated<[EmittedLogLine]>([])
  ClerkLogger.sink = { level, text in
    lines.withValue { $0.append(EmittedLogLine(level: level, text: text)) }
  }
  return lines
}

@MainActor
private func restoreLogSink() {
  ClerkLogger.sink = originalLogSink
}

@MainActor
private let originalLogSink = ClerkLogger.sink

@MainActor
private func waitForLine(
  containing needle: String,
  in lines: LockIsolated<[EmittedLogLine]>
) async throws -> EmittedLogLine {
  let deadline = ContinuousClock.now + .seconds(1)
  while !lines.value.contains(where: { $0.text.contains(needle) }), ContinuousClock.now < deadline {
    await Task.yield()
  }
  return try #require(lines.value.first { $0.text.contains(needle) })
}

private final class PreInstallationDeleteFailingKeychain: @unchecked Sendable,
  KeychainStorage
{
  enum Failure: Error {
    case delete
  }

  private let backing = InMemoryKeychain()

  func set(_ data: Data, forKey key: String) throws {
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try backing.data(forKey: key)
  }

  func deleteItem(forKey _: String) throws {
    throw Failure.delete
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }
}
