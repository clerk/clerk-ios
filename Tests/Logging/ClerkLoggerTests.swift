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
  func info_WithDefaultForce_RespectsLogLevel() async {
    Clerk.configure(publishableKey: testPublishableKey, options: Clerk.Options(logLevel: .error))
    let (lines, restoreSink) = captureLogLines()
    defer { restoreSink() }

    await ClerkLogger.info("default-force info").value

    #expect(lines.lines(containing: "default-force info").isEmpty)
  }

  @Test
  func info_WithForceTrue_AlwaysLogs() async throws {
    Clerk.configure(publishableKey: testPublishableKey, options: Clerk.Options(logLevel: .error))
    let (lines, restoreSink) = captureLogLines()
    defer { restoreSink() }

    await ClerkLogger.info("forced info", force: true).value

    let line = try #require(lines.lines(containing: "forced info").only)
    #expect(line.level == .info)
    #expect(line.text.contains("[INFO]"))
    #expect(line.text.hasSuffix("- 🚨 forced info"))
  }

  @Test
  func info_WithForceFalse_RespectsLogLevel() async {
    Clerk.configure(publishableKey: testPublishableKey, options: Clerk.Options(logLevel: .error))
    let (lines, restoreSink) = captureLogLines()
    defer { restoreSink() }

    await ClerkLogger.info("unforced info", force: false).value

    #expect(lines.lines(containing: "unforced info").isEmpty)
  }

  @Test
  func info_WithInfoLogLevel_LogsWithoutForce() async throws {
    Clerk.configure(publishableKey: testPublishableKey, options: Clerk.Options(logLevel: .info))
    let (lines, restoreSink) = captureLogLines()
    defer { restoreSink() }

    await ClerkLogger.info("info at info level").value

    let line = try #require(lines.lines(containing: "info at info level").only)
    #expect(line.level == .info)
    #expect(line.text.hasSuffix("- info at info level"))
    #expect(!line.text.contains("🚨"))
  }

  @Test
  func info_WithForceTrue_DoesNotTriggerErrorCallback() async {
    let entries = LockIsolated<[LogEntry]>([])
    let options = Clerk.Options(
      logLevel: .error,
      loggerHandler: { entry in
        entries.withValue { $0.append(entry) }
      }
    )
    Clerk.configure(publishableKey: testPublishableKey, options: options)
    let (lines, restoreSink) = captureLogLines()
    defer { restoreSink() }

    await ClerkLogger.info("forced info", force: true).value
    #expect(lines.lines(containing: "forced info").count == 1)
    #expect(entries.value.isEmpty)

    await ClerkLogger.error("error after info").value
    #expect(entries.value.map(\.message) == ["error after info"])
  }

  @Test
  func error_AlwaysLogsRegardlessOfLogLevel() async throws {
    Clerk.configure(publishableKey: testPublishableKey, options: Clerk.Options(logLevel: .error))
    let (lines, restoreSink) = captureLogLines()
    defer { restoreSink() }

    await ClerkLogger.error("error message", error: URLError(.badURL)).value

    let line = try #require(lines.lines(containing: "error message").only)
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

extension Array {
  fileprivate var only: Element? {
    count == 1 ? first : nil
  }
}

extension LockIsolated<[EmittedLogLine]> {
  fileprivate func lines(containing needle: String) -> [EmittedLogLine] {
    value.filter { $0.text.contains(needle) }
  }
}

private struct EmittedLogLine {
  let level: LogLevel
  let text: String
}

@MainActor
private func captureLogLines() -> (LockIsolated<[EmittedLogLine]>, @MainActor () -> Void) {
  let original = ClerkLogger.sink
  let lines = LockIsolated<[EmittedLogLine]>([])
  ClerkLogger.sink = { level, text in
    lines.withValue { $0.append(EmittedLogLine(level: level, text: text)) }
  }
  return (lines, { ClerkLogger.sink = original })
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
