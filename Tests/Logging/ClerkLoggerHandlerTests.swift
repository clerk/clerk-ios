//
//  ClerkLoggerHandlerTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct ClerkLoggerHandlerTests {
  /// Test that the logger handler is called when an error is logged
  @Test
  func handlerIsCalledWhenErrorIsLogged() async {
    let receivedEntry = LockIsolated<LogEntry?>(nil)

    // Configure Clerk with a handler that captures the entry
    let handler: @Sendable (LogEntry) -> Void = { entry in
      receivedEntry.setValue(entry)
    }

    let options = Clerk.ClerkOptions(loggerHandler: handler)
    Clerk.configure(publishableKey: testPublishableKey, options: options)
    setupMockAPIClient()

    ClerkLogger.error("Test error message")

    // Wait for handler to be called
    await waitFor { receivedEntry.value != nil }

    #expect(receivedEntry.value != nil)
    #expect(receivedEntry.value?.message == "Test error message")
    #expect(receivedEntry.value?.level == .error)
  }

  /// Test that the handler receives correct LogEntry properties
  @Test
  func handlerReceivesCorrectLogEntryProperties() async {
    let receivedEntry = LockIsolated<LogEntry?>(nil)

    let handler: @Sendable (LogEntry) -> Void = { entry in
      receivedEntry.setValue(entry)
    }

    let options = Clerk.ClerkOptions(loggerHandler: handler)
    Clerk.configure(publishableKey: testPublishableKey, options: options)
    setupMockAPIClient()

    let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error description"])
    ClerkLogger.error("Test error", error: testError)

    await waitFor { receivedEntry.value != nil }

    guard let entry = receivedEntry.value else {
      Issue.record("Handler was not called")
      return
    }

    #expect(entry.message == "Test error")
    #expect(entry.level == .error)
    #expect(entry.error != nil)
    #expect(entry.file.contains("ClerkLoggerHandlerTests.swift"))
    #expect(entry.function.contains("handlerReceivesCorrectLogEntryProperties"))
    #expect(entry.line > 0)
    #expect(entry.timestamp <= Date())
    #expect(entry.formattedMessage.contains("Test error"))
    #expect(entry.formattedMessage.contains("Error:"))
  }

  /// Test that handler is not called for non-error log levels
  @Test
  func handlerIsNotCalledForNonErrorLevels() async {
    let handlerCalled = LockIsolated(false)

    let handler: @Sendable (LogEntry) -> Void = { _ in
      handlerCalled.setValue(true)
    }

    let options = Clerk.ClerkOptions(loggerHandler: handler)
    Clerk.configure(publishableKey: testPublishableKey, options: options)
    setupMockAPIClient()

    ClerkLogger.warning("Test warning")
    ClerkLogger.info("Test info")
    ClerkLogger.debug("Test debug")
    ClerkLogger.verbose("Test verbose")

    // Give async operations a chance to complete
    await Task.yield()

    #expect(handlerCalled.value == false)
  }

  /// Test that handler works with LocalizedError
  @Test
  func handlerWorksWithLocalizedError() async {
    struct TestLocalizedError: LocalizedError {
      var errorDescription: String? { "Localized error description" }
      var failureReason: String? { "Failure reason" }
    }

    let receivedEntry = LockIsolated<LogEntry?>(nil)

    let handler: @Sendable (LogEntry) -> Void = { entry in
      receivedEntry.setValue(entry)
    }

    let options = Clerk.ClerkOptions(loggerHandler: handler)
    Clerk.configure(publishableKey: testPublishableKey, options: options)
    setupMockAPIClient()

    let testError = TestLocalizedError()
    ClerkLogger.error("Test localized error", error: testError)

    await waitFor { receivedEntry.value != nil }

    guard let entry = receivedEntry.value else {
      Issue.record("Handler was not called")
      return
    }

    #expect(entry.error != nil)
    #expect(entry.formattedMessage.contains("Localized error description"))
    #expect(entry.formattedMessage.contains("Failure reason"))
  }

  /// Test that handler works with logError convenience method
  @Test
  func handlerWorksWithLogErrorConvenienceMethod() async {
    let receivedEntry = LockIsolated<LogEntry?>(nil)

    let handler: @Sendable (LogEntry) -> Void = { entry in
      receivedEntry.setValue(entry)
    }

    let options = Clerk.ClerkOptions(loggerHandler: handler)
    Clerk.configure(publishableKey: testPublishableKey, options: options)
    setupMockAPIClient()

    let testError = NSError(domain: "TestDomain", code: 456)
    ClerkLogger.logError(testError, message: "Custom error message")

    await waitFor { receivedEntry.value != nil }

    #expect(receivedEntry.value?.message == "Custom error message")
    #expect(receivedEntry.value?.error != nil)
  }

  /// Test that handler works with logNetworkError convenience method
  @Test
  func handlerWorksWithLogNetworkErrorConvenienceMethod() async {
    let receivedEntry = LockIsolated<LogEntry?>(nil)

    let handler: @Sendable (LogEntry) -> Void = { entry in
      receivedEntry.setValue(entry)
    }

    let options = Clerk.ClerkOptions(loggerHandler: handler)
    Clerk.configure(publishableKey: testPublishableKey, options: options)
    setupMockAPIClient()

    let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
    ClerkLogger.logNetworkError(networkError, endpoint: "/v1/test", statusCode: 500)

    await waitFor { receivedEntry.value != nil }

    guard let entry = receivedEntry.value else {
      Issue.record("Handler was not called")
      return
    }

    #expect(entry.message.contains("Network request failed"))
    #expect(entry.message.contains("/v1/test"))
    #expect(entry.message.contains("500"))
    #expect(entry.error != nil)
  }

  /// Test that handler is not called when nil
  @Test
  func handlerIsNotCalledWhenNil() async {
    // Configure Clerk with no handler
    let options = Clerk.ClerkOptions(loggerHandler: nil)
    Clerk.configure(publishableKey: testPublishableKey, options: options)
    setupMockAPIClient()

    ClerkLogger.error("Test error")

    // Give async operations a chance to complete
    await Task.yield()

    // Handler should not be called since it's nil
    // This test verifies the system doesn't crash when handler is nil
  }

  /// Test that multiple errors trigger handler multiple times
  @Test
  func handlerIsCalledForMultipleErrors() async {
    let entries = LockIsolated<[LogEntry]>([])

    let handler: @Sendable (LogEntry) -> Void = { entry in
      entries.withValue { $0.append(entry) }
    }

    let options = Clerk.ClerkOptions(loggerHandler: handler)
    Clerk.configure(publishableKey: testPublishableKey, options: options)
    setupMockAPIClient()

    ClerkLogger.error("Error 1")
    await waitFor { entries.value.count >= 1 }

    ClerkLogger.error("Error 2")
    await waitFor { entries.value.count >= 2 }

    ClerkLogger.error("Error 3")
    await waitFor { entries.value.count >= 3 }

    #expect(entries.value.count == 3)
    #expect(entries.value[0].message == "Error 1")
    #expect(entries.value[1].message == "Error 2")
    #expect(entries.value[2].message == "Error 3")
  }

  /// Helper to wait for a condition to become true
  private func waitFor(condition: @escaping @Sendable () -> Bool, timeout: TimeInterval = 1.0) async {
    let startTime = Date()
    while !condition() && Date().timeIntervalSince(startTime) < timeout {
      await Task.yield()
    }
  }
}
