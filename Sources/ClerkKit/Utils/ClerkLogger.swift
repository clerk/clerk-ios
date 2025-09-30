import Foundation

// MARK: - Log Types

public enum ClerkLogLevel: Int, Codable, Sendable, CustomStringConvertible {
  case debug = 0
  case info
  case warning
  case error
  case none

  public var description: String {
    switch self {
    case .debug:
      return "DEBUG"
    case .info:
      return "INFO"
    case .warning:
      return "WARNING"
    case .error:
      return "ERROR"
    case .none:
      return "NONE"
    }
  }

  var emoji: String {
    switch self {
    case .debug:
      return "🔍"
    case .info:
      return "ℹ️"
    case .warning:
      return "⚠️"
    case .error:
      return "❌"
    case .none:
      return ""
    }
  }
}

public enum ClerkLogScope: Int, Codable, Sendable, CustomStringConvertible {
  case core
  case network
  case auth
  case session
  case keychain
  case telemetry
  case environment
  case ui
  case all

  public var description: String {
    switch self {
    case .core:
      return "core"
    case .network:
      return "network"
    case .auth:
      return "auth"
    case .session:
      return "session"
    case .keychain:
      return "keychain"
    case .telemetry:
      return "telemetry"
    case .environment:
      return "environment"
    case .ui:
      return "ui"
    case .all:
      return "all"
    }
  }
}

private protocol ClerkLoggable {
  static func shouldLog(level: ClerkLogLevel, scope: ClerkLogScope) -> Bool
  static func emit(
    level: ClerkLogLevel,
    scope: ClerkLogScope,
    message: String?,
    info: [String: Any]?,
    error: Error?
  )
}

// MARK: - Logger
@_spi(Internal)
public enum ClerkLogger: ClerkLoggable {
  static func shouldLog(level: ClerkLogLevel, scope: ClerkLogScope) -> Bool {
    var logging = ClerkOptions.Logging()

    if Clerk.isInitialized {
      logging = Clerk.shared.options.logging
    }

    guard logging.level != .none else {
      return false
    }

    let meetsLevel = level.rawValue >= logging.level.rawValue
    let isInScope = logging.scopes.contains(scope) || logging.scopes.contains(.all)

    return meetsLevel && isInScope
  }

  static func emit(
    level: ClerkLogLevel,
    scope: ClerkLogScope,
    message: String?,
    info: [String: Any]?,
    error: Error?
  ) {
    Task.detached(priority: .utility) {
      guard shouldLog(level: level, scope: scope) else {
        return
      }

      var dumping: [String: Any] = [:]

      if let info {
        dumping["info"] = info
      }

      if let error {
        dumping["error"] = error
      }

      var name = "\(Date().clerkLogTimestamp) \(level.emoji) [Clerk] [\(scope.description)] - \(level.description)"

      if let message, !message.isEmpty {
        name += ": \(message)"
      }

      if dumping.isEmpty {
        print(name)
      } else {
        dump(
          dumping,
          name: name,
          indent: 0,
          maxDepth: 50,
          maxItems: 200
        )
      }
    }
  }

  private static func log(
    level: ClerkLogLevel,
    scope: ClerkLogScope,
    message: String?,
    info: [String: Any]?,
    error: Error?
  ) {
    emit(level: level, scope: scope, message: message, info: info, error: error)
  }

  public static func debug(
    _ message: String?,
    scope: ClerkLogScope = .core,
    info: [String: Any]? = nil,
    error: Error? = nil
  ) {
    log(level: .debug, scope: scope, message: message, info: info, error: error)
  }

  public static func info(
    _ message: String?,
    scope: ClerkLogScope = .core,
    info: [String: Any]? = nil,
    error: Error? = nil
  ) {
    log(level: .info, scope: scope, message: message, info: info, error: error)
  }

  public static func warning(
    _ message: String?,
    scope: ClerkLogScope = .core,
    info: [String: Any]? = nil,
    error: Error? = nil
  ) {
    log(level: .warning, scope: scope, message: message, info: info, error: error)
  }

  public static func error(
    _ message: String?,
    scope: ClerkLogScope = .core,
    info: [String: Any]? = nil,
    error: Error? = nil
  ) {
    log(level: .error, scope: scope, message: message, info: info, error: error)
  }

  public static func logError(
    _ error: Error,
    message: String = "An error occurred",
    scope: ClerkLogScope = .core
  ) {
    self.error(message, scope: scope, error: error)
  }

  public static func logNetworkError(
    _ error: Error,
    endpoint: String,
    statusCode: Int? = nil
  ) {
    var info: [String: Any] = [
      "endpoint": endpoint
    ]
    if let statusCode {
      info["statusCode"] = statusCode
    }
    self.error(
      "Network request failed",
      scope: .network,
      info: info,
      error: error
    )
  }
}

// MARK: - Date helper
private extension Date {
  var clerkLogTimestamp: String {
    ClerkLogger.dateFormatter.string(from: self)
  }
}

private extension ClerkLogger {
  static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
  }()
}
