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
  func info_WithDefaultForce_RespectsLogLevel() {
    let options = Clerk.Options(logLevel: .error)
    Clerk.configure(publishableKey: testPublishableKey, options: options)

    let shouldLog = ClerkLogger.shouldLog(level: .info)
    #expect(shouldLog == false)
  }

  @Test
  func info_WithForceTrue_AlwaysLogs() {
    let options = Clerk.Options(logLevel: .error)
    Clerk.configure(publishableKey: testPublishableKey, options: options)

    ClerkLogger.info("Test message", force: true)
  }

  @Test
  func info_WithForceFalse_RespectsLogLevel() {
    let options = Clerk.Options(logLevel: .error)
    Clerk.configure(publishableKey: testPublishableKey, options: options)

    let shouldLog = ClerkLogger.shouldLog(level: .info)
    #expect(shouldLog == false)

    ClerkLogger.info("Test message", force: false)
  }

  @Test
  func info_WithInfoLogLevel_LogsWithoutForce() {
    let shouldLogWithError = ClerkLogger.shouldLog(level: .info)
    #expect(shouldLogWithError == false)

    let infoLevel: LogLevel = .info
    let configuredInfoLevel: LogLevel = .info
    let shouldLogWithInfo = infoLevel <= configuredInfoLevel
    #expect(shouldLogWithInfo == true)
  }

  @Test
  func info_WithForceTrue_DoesNotTriggerErrorCallback() {
    let errorCallbackInvoked = LockIsolated(false)

    let errorHandler: @Sendable (LogEntry) -> Void = { _ in
      errorCallbackInvoked.setValue(true)
    }

    let options = Clerk.Options(
      logLevel: .error,
      loggerHandler: errorHandler
    )
    Clerk.configure(publishableKey: testPublishableKey, options: options)

    ClerkLogger.info("Test message", force: true)

    #expect(errorCallbackInvoked.value == false)
  }

  @Test
  func error_AlwaysLogsRegardlessOfLogLevel() {
    let options = Clerk.Options(logLevel: .verbose)
    Clerk.configure(publishableKey: testPublishableKey, options: options)

    let errorShouldAlwaysLog = LogLevel.error <= Clerk.shared.options.logLevel
    #expect(errorShouldAlwaysLog == true)

    ClerkLogger.error("Test error message")
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

    await #expect(throws: ClerkClientError.self) {
      try await Clerk.clearLocalClerkStorageStrictly(in: dependencies)
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
