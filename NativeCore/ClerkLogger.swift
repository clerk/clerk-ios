import OSLog

package enum ClerkLogger {
  private static let logger = Logger(subsystem: "com.clerk.sdk", category: "Clerk")

  package static func error(_ message: String, error: Error? = nil) {
    let code = (error as? CoreError)?.code ?? "operation_failed"
    logger.error("\(message, privacy: .private) [\(code, privacy: .private)]")
  }

  package static func info(_ message: String, force: Bool = false) {
    if force { logger.info("\(message, privacy: .private)") }
  }
}
