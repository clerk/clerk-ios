//
//  Session+Tasks.swift
//

extension Session {
  /// The parsed tasks from pending session tasks.
  public var pendingTasks: [Task] {
    tasks ?? []
  }

  /// Whether this session requires forced MFA enrollment before activation.
  public var requiresForcedMfa: Bool {
    status == .pending && pendingTasks.contains(.setupMfa)
  }
}
