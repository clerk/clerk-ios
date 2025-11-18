//
//  ClerkLogger.swift
//  Clerk
//
//  Created by Assistant on 1/21/25.
//

import Foundation
import os.log

/// A structured representation of a log entry containing all relevant information about an error.
public struct LogEntry: Sendable {
  /// The log level (will always be `.error` for delegate callbacks).
  public let level: LogLevel

  /// The error message.
  public let message: String

  /// The error object if present.
  public let error: Error?

  /// The source file name where the error occurred.
  public let file: String

  /// The function name where the error occurred.
  public let function: String

  /// The line number where the error occurred.
  public let line: Int

  /// The timestamp when the error was logged.
  public let timestamp: Date

  /// The full formatted log message (includes emoji, level, timestamp, location, message, and error details).
  public let formattedMessage: String
}

/// Log levels for different types of messages
public enum LogLevel: String, CaseIterable, Comparable, Sendable {
  case error = "ERROR"
  case warning = "WARNING"
  case info = "INFO"
  case debug = "DEBUG"
  case verbose = "VERBOSE"

  var osLogType: OSLogType {
    switch self {
    case .error:
      .error
    case .warning:
      .default
    case .info:
      .info
    case .debug:
      .debug
    case .verbose:
      .debug
    }
  }

  var emoji: String {
    switch self {
    case .error:
      "❌"
    case .warning:
      "⚠️"
    case .info:
      "ℹ️"
    case .debug:
      "🔍"
    case .verbose:
      "🔬"
    }
  }

  /// Raw integer values for comparison (lower = more severe)
  private var severity: Int {
    switch self {
    case .error: 0
    case .warning: 1
    case .info: 2
    case .debug: 3
    case .verbose: 4
    }
  }

  public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
    lhs.severity < rhs.severity
  }
}

/// A unified logging system for the Clerk SDK that respects log level configuration.
package enum ClerkLogger {

  /// The unified logging instance for Clerk
  private static let logger = Logger(subsystem: "com.clerk.sdk", category: "Clerk")

  /// Log an error message (always logs regardless of debug mode)
  /// - Parameters:
  ///   - message: The error message to log
  ///   - error: Optional error object to include
  ///   - file: The file where the log is called (automatically filled)
  ///   - function: The function where the log is called (automatically filled)
  ///   - line: The line number where the log is called (automatically filled)
  package static func error(
    _ message: String,
    error: Error? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    logSync(level: .error, message: message, error: error, forceLog: true, file: file, function: function, line: line)
  }

  /// Log a warning message (only logs when log level is set to warning or lower)
  /// - Parameters:
  ///   - message: The warning message to log
  ///   - file: The file where the log is called (automatically filled)
  ///   - function: The function where the log is called (automatically filled)
  ///   - line: The line number where the log is called (automatically filled)
  static func warning(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    logSync(level: .warning, message: message, file: file, function: function, line: line)
  }

  /// Log an info message (only logs when log level is set to info or lower)
  /// - Parameters:
  ///   - message: The info message to log
  ///   - file: The file where the log is called (automatically filled)
  ///   - function: The function where the log is called (automatically filled)
  ///   - line: The line number where the log is called (automatically filled)
  static func info(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    logSync(level: .info, message: message, file: file, function: function, line: line)
  }

  /// Log a debug message (only logs when log level is set to debug or lower)
  /// - Parameters:
  ///   - message: The debug message to log
  ///   - file: The file where the log is called (automatically filled)
  ///   - function: The function where the log is called (automatically filled)
  ///   - line: The line number where the log is called (automatically filled)
  static func debug(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    logSync(level: .debug, message: message, file: file, function: function, line: line)
  }

  /// Log a verbose message (only logs when log level is set to verbose)
  /// - Parameters:
  ///   - message: The verbose message to log
  ///   - file: The file where the log is called (automatically filled)
  ///   - function: The function where the log is called (automatically filled)
  ///   - line: The line number where the log is called (automatically filled)
  static func verbose(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    logSync(level: .verbose, message: message, file: file, function: function, line: line)
  }

  /// Synchronous logging function that checks log level asynchronously
  /// - Parameters:
  ///   - level: The log level
  ///   - message: The message to log
  ///   - error: Optional error object
  ///   - forceLog: Force logging regardless of log level (used for errors)
  ///   - file: The source file
  ///   - function: The source function
  ///   - line: The source line number
  private static func logSync(
    level: LogLevel,
    message: String,
    error: Error? = nil,
    forceLog: Bool = false,
    file: String,
    function: String,
    line: Int
  ) {
    // Errors always log regardless of level
    if !forceLog {
      // Check log level asynchronously since Clerk.shared.options requires MainActor
      let shouldLogTask = Task { @MainActor in
        ClerkLogger.shouldLog(level: level)
      }
      // For non-async context, we'll log by default if we can't check
      // This ensures errors always log, and other levels will be filtered properly in async contexts
      Task {
        guard await shouldLogTask.value else { return }
        await performLog(level: level, message: message, error: error, file: file, function: function, line: line)
      }
      return
    }

    // For forceLog (errors), log immediately
    Task {
      await performLog(level: level, message: message, error: error, file: file, function: function, line: line)
    }
  }

  /// Performs the actual logging
  @MainActor
  private static func performLog(
    level: LogLevel,
    message: String,
    error: Error?,
    file: String,
    function: String,
    line: Int
  ) {

    let fileName = URL(fileURLWithPath: file).lastPathComponent
    let timestampString = DateFormatter.logFormatter.string(from: Date())
    let timestamp = Date()

    var logMessage = "\(level.emoji) [\(level.rawValue)] \(timestampString) \(fileName):\(line) \(function) - \(message)"

    if let error {
      logMessage += "\n   Error: \(error)"

      // Include localized description if available
      if let localizedError = error as? LocalizedError,
         let description = localizedError.errorDescription
      {
        logMessage += "\n   Description: \(description)"
      }

      // Include failure reason if available
      if let localizedError = error as? LocalizedError,
         let failureReason = localizedError.failureReason
      {
        logMessage += "\n   Reason: \(failureReason)"
      }
    }

    // Use unified logging for structured logs only (avoid duplicate console output)
    logger.log(level: level.osLogType, "\(logMessage)")

    // Invoke delegate for errors only
    if level == .error {
      let logEntry = LogEntry(
        level: level,
        message: message,
        error: error,
        file: fileName,
        function: function,
        line: line,
        timestamp: timestamp,
        formattedMessage: logMessage
      )

      // Capture handler closure while we're on MainActor (where Clerk.shared is safe to access)
      // This avoids issues if Clerk isn't configured yet or if we're in a detached context
      let handler = Clerk.shared.options.loggerHandler

      // Invoke handler asynchronously to avoid blocking
      if let handler {
        Task.detached {
          handler(logEntry)
        }
      }
    }
  }

  /// Determines if a message at the given level should be logged based on the configured log level
  @MainActor
  static func shouldLog(level: LogLevel) -> Bool {
    let configuredLevel = Clerk.shared.options.logLevel
    // Log if the message level is >= configured level (lower severity number = higher priority)
    return level >= configuredLevel
  }
}

// MARK: - Convenience Extensions

package extension ClerkLogger {
  /// Log an error with automatic error extraction
  /// - Parameters:
  ///   - error: The error to log
  ///   - message: Optional custom message (defaults to "An error occurred")
  ///   - file: The file where the log is called (automatically filled)
  ///   - function: The function where the log is called (automatically filled)
  ///   - line: The line number where the log is called (automatically filled)
  static func logError(
    _ error: Error,
    message: String = "An error occurred",
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    logSync(level: .error, message: message, error: error, forceLog: true, file: file, function: function, line: line)
  }

  /// Log a network request error with additional context
  /// - Parameters:
  ///   - error: The network error
  ///   - endpoint: The API endpoint that failed
  ///   - statusCode: HTTP status code if available
  ///   - file: The file where the log is called (automatically filled)
  ///   - function: The function where the log is called (automatically filled)
  ///   - line: The line number where the log is called (automatically filled)
  static func logNetworkError(
    _ error: Error,
    endpoint: String,
    statusCode: Int? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    var message = "Network request failed for endpoint: \(endpoint)"
    if let statusCode {
      message += " (Status: \(statusCode))"
    }
    logSync(level: .error, message: message, error: error, forceLog: true, file: file, function: function, line: line)
  }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
  static let logFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
}
