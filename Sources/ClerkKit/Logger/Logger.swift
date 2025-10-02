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

// MARK: - Logger
@_spi(Internal)
public enum Logger {
  public static func log(
    level: ClerkLogLevel,
    scope: ClerkLogScope = .core,
    message: String? = nil,
    info: [String: Any]? = nil,
    error: Error? = nil,
    file: StaticString = #fileID,
    line: UInt = #line
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

      dumping["source"] = "\(file):\(line)"

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

}

// MARK: - Date helper
private extension Date {
  var clerkLogTimestamp: String {
    Logger.dateFormatter.string(from: self)
  }
}

private extension Logger {
  static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
  }()
}
