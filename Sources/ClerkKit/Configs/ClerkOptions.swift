import Foundation

/// Options for configuring Clerk behaviour.
///
/// Modeled after Superwall's simple options container, this class groups
/// together the small set of user-configurable knobs we expose in the new
/// major version without any automatic binding or change observation.
public final class ClerkOptions: Sendable, Encodable {

    /// Logging configuration used by the SDK.
    public var logging: Logging

    /// Telemetry configuration for non-essential analytics.
    public var telemetry: Telemetry

    /// Keychain storage options for persisted state.
    public var keychain: Keychain

    /// Redirect configuration used for OAuth and deep link handling.
    public var redirect: Redirect

    public init(
        logging: Logging = .init(),
        telemetry: Telemetry = .init(),
        keychain: Keychain = .init(),
        redirect: Redirect = .init()
    ) {
        self.logging = logging
        self.telemetry = telemetry
        self.keychain = keychain
        self.redirect = redirect
    }

}

// MARK: - Logging

extension ClerkOptions {

    public final class Logging: Sendable, Encodable {

        public enum Level: String, Codable {
            case off
            case error
            case warning
            case info
            case debug
        }

        public var level: Level
        public var attachClientRequestMetadata: Bool

        public init(
            level: Level = .info,
            attachClientRequestMetadata: Bool = false
        ) {
            self.level = level
            self.attachClientRequestMetadata = attachClientRequestMetadata
        }
    }
}

// MARK: - Telemetry

extension ClerkOptions {

    public final class Telemetry: Sendable, Encodable {

        /// Controls whether optional telemetry events are emitted.
        public var isEnabled: Bool

        public init(isEnabled: Bool = true) {
            self.isEnabled = isEnabled
        }
    }
}

// MARK: - Keychain

extension ClerkOptions {

    public final class Keychain: Sendable, Encodable {

        /// Name of the service under which items are saved. Defaults to the bundle identifier.
        public var service: String

        /// Optional access group for sharing items.
        public var accessGroup: String?

        public init(
            service: String = Bundle.main.bundleIdentifier ?? "",
            accessGroup: String? = nil
        ) {
            self.service = service
            self.accessGroup = accessGroup
        }
    }
}

// MARK: - Redirect

extension ClerkOptions {

    public final class Redirect: Sendable, Encodable {

        /// Redirect URL used when returning from OAuth providers.
        public var redirectURL: String

        /// URL scheme listened to by Clerk for OAuth callbacks.
        public var callbackURLScheme: String

        public init(
            redirectURL: String = "\(Bundle.main.bundleIdentifier ?? "")://callback",
            callbackURLScheme: String = Bundle.main.bundleIdentifier ?? ""
        ) {
            self.redirectURL = redirectURL
            self.callbackURLScheme = callbackURLScheme
        }
    }
}

// MARK: - Convenience helpers

extension ClerkOptions.Logging.Level {
    /// Whether informational logs should be emitted for the current level.
    var allowsInfoLogging: Bool {
        switch self {
        case .off, .error, .warning:
            return false
        case .info, .debug:
            return true
        }
    }

    /// Whether debug-level diagnostics should be emitted for the current level.
    var allowsDebugLogging: Bool {
        self == .debug
    }
}


