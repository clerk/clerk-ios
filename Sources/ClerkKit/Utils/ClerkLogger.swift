//
//  ClerkLogger.swift
//  Clerk
//
//  Created by Assistant on 1/21/25.
//

import Foundation
import os.log

/// A unified logging system for the Clerk SDK that respects the debugMode setting.
package struct ClerkLogger {

  /// Log levels for different types of messages
  enum LogLevel: String, CaseIterable {
    case error = "ERROR"
    case warning = "WARNING"
    case info = "INFO"
    case debug = "DEBUG"

    var osLogType: OSLogType {
      switch self {
      case .error:
        return .error
      case .warning:
        return .default
      case .info:
        return .info
      case .debug:
        return .debug
      }
    }

    var emoji: String {
      switch self {
      case .error:
        return "❌"
      case .warning:
        return "⚠️"
      case .info:
        return "ℹ️"
      case .debug:
        return "🔍"
      }
    }
  }

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

  /// Log a warning message (only logs when debug mode is enabled)
  /// - Parameters:
  ///   - message: The warning message to log
  ///   - debugMode: Override debug mode setting (optional)
  ///   - file: The file where the log is called (automatically filled)
  ///   - function: The function where the log is called (automatically filled)
  ///   - line: The line number where the log is called (automatically filled)
  static func warning(
    _ message: String,
    debugMode: Bool? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    logSync(level: .warning, message: message, debugModeOverride: debugMode, file: file, function: function, line: line)
  }

  /// Log an info message (only logs when debug mode is enabled)
  /// - Parameters:
  ///   - message: The info message to log
  ///   - debugMode: Override debug mode setting (optional)
  ///   - file: The file where the log is called (automatically filled)
  ///   - function: The function where the log is called (automatically filled)
  ///   - line: The line number where the log is called (automatically filled)
  static func info(
    _ message: String,
    debugMode: Bool? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    logSync(level: .info, message: message, debugModeOverride: debugMode, file: file, function: function, line: line)
  }

  /// Log a debug message (only logs when debug mode is enabled)
  /// - Parameters:
  ///   - message: The debug message to log
  ///   - debugMode: Override debug mode setting (optional)
  ///   - file: The file where the log is called (automatically filled)
  ///   - function: The function where the log is called (automatically filled)
  ///   - line: The line number where the log is called (automatically filled)
  static func debug(
    _ message: String,
    debugMode: Bool? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    logSync(level: .debug, message: message, debugModeOverride: debugMode, file: file, function: function, line: line)
  }

  /// Synchronous logging function that doesn't require MainActor access
  /// - Parameters:
  ///   - level: The log level
  ///   - message: The message to log
  ///   - error: Optional error object
  ///   - forceLog: Force logging regardless of debug mode (used for errors)
  ///   - debugModeOverride: Override the debug mode setting
  ///   - file: The source file
  ///   - function: The source function
  ///   - line: The source line number
  private static func logSync(
    level: LogLevel,
    message: String,
    error: Error? = nil,
    forceLog: Bool = false,
    debugModeOverride: Bool? = nil,
    file: String,
    function: String,
    line: Int
  ) {
    // Determine if we should log
    let shouldLog: Bool
    if forceLog {
      shouldLog = true
    } else if let override = debugModeOverride {
      shouldLog = override
    } else {
      // No override provided; default to not logging from this sync context
      shouldLog = false
    }

    guard shouldLog else { return }

    let fileName = URL(fileURLWithPath: file).lastPathComponent
    let timestamp = DateFormatter.logFormatter.string(from: Date())

    var logMessage = "\(level.emoji) [\(level.rawValue)] \(timestamp) \(fileName):\(line) \(function) - \(message)"

    if let error = error {
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
    if let statusCode = statusCode {
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
