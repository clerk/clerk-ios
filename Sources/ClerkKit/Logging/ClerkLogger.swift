//
//  ClerkLogger.swift
//  Clerk
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

package enum ClerkLogger {
  package struct Configuration {
    let logLevel: LogLevel
    let handler: (@Sendable (LogEntry) -> Void)?

    init(options: Clerk.Options) {
      logLevel = options.logLevel
      handler = options.loggerHandler
    }
  }

  private struct Context {
    let file: String
    let function: String
    let line: Int
    let configuration: Configuration?
  }

  private static let logger = Logger(subsystem: "com.clerk.sdk", category: "Clerk")

  /// Receives each formatted log line. Tests replace it to observe what gets emitted.
  @MainActor
  static var sink: (LogLevel, String) -> Void = { level, message in
    logger.log(level: level.osLogType, "\(message)")
  }

  /// Log an error message (always logs regardless of debug mode)
  /// - Parameters:
  ///   - message: The error message to log
  ///   - error: Optional error object to include
  ///   - file: The file where the log is called (automatically filled)
  ///   - function: The function where the log is called (automatically filled)
  ///   - line: The line number where the log is called (automatically filled)
  @discardableResult
  package static func error(
    _ message: String,
    error: Error? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) -> Task<Void, Never> {
    logSync(level: .error, message: message, error: error, forceLog: true, file: file, function: function, line: line)
  }

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
  ///   - force: If `true`, always logs regardless of log level configuration. Defaults to `false`.
  ///   - file: The file where the log is called (automatically filled)
  ///   - function: The function where the log is called (automatically filled)
  ///   - line: The line number where the log is called (automatically filled)
  @discardableResult
  package static func info(
    _ message: String,
    force: Bool = false,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) -> Task<Void, Never> {
    logSync(level: .info, message: message, forceLog: force, file: file, function: function, line: line)
  }

  static func debug(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    logSync(level: .debug, message: message, file: file, function: function, line: line)
  }

  static func verbose(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    logSync(level: .verbose, message: message, file: file, function: function, line: line)
  }

  @discardableResult
  private static func logSync(
    level: LogLevel,
    message: String,
    error: Error? = nil,
    forceLog: Bool = false,
    file: String,
    function: String,
    line: Int,
    configuration: Configuration? = nil
  ) -> Task<Void, Never> {
    if !forceLog {
      let shouldLogTask = Task { @MainActor in
        ClerkLogger.shouldLog(level: level, configuration: configuration)
      }
      return Task {
        guard await shouldLogTask.value else { return }
        let context = Context(
          file: file,
          function: function,
          line: line,
          configuration: configuration
        )
        await performLog(
          level: level,
          message: message,
          error: error,
          forceLog: false,
          context: context
        )?.value
      }
    }

    return Task {
      let context = Context(
        file: file,
        function: function,
        line: line,
        configuration: configuration
      )
      await performLog(
        level: level,
        message: message,
        error: error,
        forceLog: true,
        context: context
      )?.value
    }
  }

  @MainActor
  private static func performLog(
    level: LogLevel,
    message: String,
    error: Error?,
    forceLog: Bool,
    context: Context
  ) -> Task<Void, Never>? {
    let file = context.file
    let function = context.function
    let line = context.line
    let fileName = URL(fileURLWithPath: file).lastPathComponent
    let timestampString = DateFormatter.logFormatter.string(from: Date())
    let timestamp = Date()

    let forceIndicator = forceLog ? "🚨 " : ""
    var logMessage = "\(level.emoji) [\(level.rawValue)] \(timestampString) \(fileName):\(line) \(function) - \(forceIndicator)\(message)"

    if let error {
      logMessage += "\n   Error: \(error)"

      if let localizedError = error as? LocalizedError,
         let description = localizedError.errorDescription
      {
        logMessage += "\n   Description: \(description)"
      }

      if let localizedError = error as? LocalizedError,
         let failureReason = localizedError.failureReason
      {
        logMessage += "\n   Reason: \(failureReason)"
      }
    }

    sink(level, logMessage)

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

      let handler = if let configuration = context.configuration {
        configuration.handler
      } else {
        Clerk.installedLoggingConfiguration?.handler
      }

      // Invoke handler asynchronously to avoid blocking
      if let handler {
        return Task.detached {
          handler(logEntry)
        }
      }
    }
    return nil
  }

  @MainActor
  static func shouldLog(
    level: LogLevel,
    configuration: Configuration? = nil
  ) -> Bool {
    let configuredLevel = configuration?.logLevel
      ?? Clerk.installedLoggingConfiguration?.logLevel
      ?? .error
    return level <= configuredLevel
  }
}

// MARK: - Convenience Extensions

extension ClerkLogger {
  package static func logError(
    _ error: Error,
    message: String = "An error occurred",
    configuration: Configuration? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    logSync(
      level: .error,
      message: message,
      error: error,
      forceLog: true,
      file: file,
      function: function,
      line: line,
      configuration: configuration
    )
  }

  @discardableResult
  package static func logNetworkError(
    _ error: Error,
    endpoint: String,
    statusCode: Int? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) -> Task<Void, Never> {
    var message = "Network request failed for endpoint: \(endpoint)"
    if let statusCode {
      message += " (Status: \(statusCode))"
    }
    return logSync(level: .error, message: message, error: error, forceLog: false, file: file, function: function, line: line)
  }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
  fileprivate static let logFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
}
