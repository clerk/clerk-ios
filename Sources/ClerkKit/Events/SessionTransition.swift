//
//  SessionTransition.swift
//  Clerk
//

/// Describes how the current session changed between two `Client` snapshots.
///
/// The SDK computes this once inside `Clerk.client.didSet` so that every
/// consumer can pattern-match on the result instead of tracking
/// `previousSession` state themselves.
public enum SessionTransition: Sendable, Equatable {
  /// A session became active (or switched to a different active session).
  /// A valid JWT is now available.
  case activated(session: Session)

  /// A session became pending. Authenticated but needs task completion before JWT is available.
  case pending(session: Session)

  /// No usable session exists. The user is no longer authenticated.
  case unauthenticated

  /// The current session was updated but its auth state didn't change
  /// (same ID, same status — e.g. user info, org, or tasks changed).
  case updated(session: Session)
}

extension SessionTransition {
  /// The session associated with this transition, if any.
  public var session: Session? {
    switch self {
    case .activated(let session), .pending(let session), .updated(let session):
      session
    case .unauthenticated:
      nil
    }
  }
}

extension SessionTransition {
  /// Computes the transition that occurred between two session snapshots.
  ///
  /// | From → To | Result |
  /// |-----------|--------|
  /// | nil → active | `.activated` |
  /// | nil → pending | `.pending` |
  /// | pending → active (same/diff ID) | `.activated` |
  /// | active → active (diff ID) | `.activated` |
  /// | active → active (same ID) | `.updated` |
  /// | active → pending | `.pending` |
  /// | pending → pending (diff ID) | `.pending` |
  /// | pending → pending (same ID) | `.updated` |
  /// | active/pending → nil | `.unauthenticated` |
  /// | any → terminal status | `.unauthenticated` |
  init(from oldSession: Session?, to newSession: Session?) {
    guard let newSession else {
      self = .unauthenticated
      return
    }

    switch newSession.status {
    case .active:
      if oldSession?.status != .active || oldSession?.id != newSession.id {
        self = .activated(session: newSession)
      } else {
        self = .updated(session: newSession)
      }
    case .pending:
      if oldSession?.status != .pending || oldSession?.id != newSession.id {
        self = .pending(session: newSession)
      } else {
        self = .updated(session: newSession)
      }
    default:
      self = .unauthenticated
    }
  }
}
