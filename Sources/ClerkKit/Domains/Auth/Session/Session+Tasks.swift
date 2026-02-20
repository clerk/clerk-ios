//
//  Session+Tasks.swift
//

extension Session {
  /// Known session task keys that require user action before activation.
  public enum TaskKey: Equatable, Sendable {
    case mfaRequired
    case unknown(String)

    public init(rawValue: String) {
      switch rawValue.lowercased() {
      case "setup_mfa", "setup-mfa", "mfa_required", "mfa-required":
        self = .mfaRequired
      default:
        self = .unknown(rawValue)
      }
    }
  }

  /// Whether this session requires forced MFA enrollment before activation.
  public var requiresForcedMfa: Bool {
    status == .pending && (tasks ?? []).contains { TaskKey(rawValue: $0.key) == .mfaRequired }
  }
}
