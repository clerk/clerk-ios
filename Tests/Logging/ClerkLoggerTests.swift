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
@Suite(.tags(.unit))
struct ClerkLoggerTests {
  init() {
    ClerkLogger.resetConfiguration()
  }

  @Test
  func info_WithDefaultForce_RespectsLogLevel() {
    ClerkLogger.configure(logLevel: .error, handler: nil)

    let shouldLog = ClerkLogger.shouldLog(level: .info)
    #expect(shouldLog == false)
  }

  @Test
  func info_WithForceTrue_AlwaysLogs() {
    ClerkLogger.configure(logLevel: .error, handler: nil)

    ClerkLogger.info("Test message", force: true)
  }

  @Test
  func info_WithForceFalse_RespectsLogLevel() {
    ClerkLogger.configure(logLevel: .error, handler: nil)

    let shouldLog = ClerkLogger.shouldLog(level: .info)
    #expect(shouldLog == false)

    ClerkLogger.info("Test message", force: false)
  }

  @Test
  func info_WithInfoLogLevel_LogsWithoutForce() {
    ClerkLogger.configure(logLevel: .info, handler: nil)

    let shouldLogWithInfo = ClerkLogger.shouldLog(level: .info)
    #expect(shouldLogWithInfo == true)
  }

  @Test
  func info_WithForceTrue_DoesNotTriggerErrorCallback() {
    let errorCallbackInvoked = LockIsolated(false)

    let errorHandler: @Sendable (LogEntry) -> Void = { _ in
      errorCallbackInvoked.setValue(true)
    }

    ClerkLogger.configure(logLevel: .error, handler: errorHandler)

    ClerkLogger.info("Test message", force: true)

    #expect(errorCallbackInvoked.value == false)
  }

  @Test
  func error_AlwaysLogsRegardlessOfLogLevel() {
    ClerkLogger.configure(logLevel: .verbose, handler: nil)

    let errorShouldAlwaysLog = ClerkLogger.shouldLog(level: .error)
    #expect(errorShouldAlwaysLog == true) // error (0) <= verbose (4)

    ClerkLogger.error("Test error message")
  }
}
