import Foundation

struct CheckAuthorizationParams: Equatable {
  var role: String?
  var permission: String?
  var feature: String?
  var plan: String?
  var reverification: ReverificationConfig?

  init(
    role: String? = nil,
    permission: String? = nil,
    feature: String? = nil,
    plan: String? = nil,
    reverification: ReverificationConfig? = nil
  ) {
    self.role = role
    self.permission = permission
    self.feature = feature
    self.plan = plan
    self.reverification = reverification
  }
}

/// How recently the user must have verified their identity.
public enum ReverificationConfig: Sendable, Equatable {
  /// Multi-factor verification within the last 10 minutes. Falls back to first-factor verification
  /// when the user has no second factor enrolled.
  case strictMfa
  /// Second-factor verification within the last 10 minutes. Falls back to first-factor verification
  /// when the user has no second factor enrolled.
  case strict
  /// Second-factor verification within the last hour. Falls back to first-factor verification when
  /// the user has no second factor enrolled.
  case moderate
  /// Second-factor verification within the last day. Falls back to first-factor verification when
  /// the user has no second factor enrolled.
  case lax
  /// Verification at `level` within the last `afterMinutes` minutes.
  case custom(level: SessionVerification.Level, afterMinutes: Int)
}

extension Session {
  /// Returns whether the user has `role` in the Active Organization, and optionally reverified
  /// within `reverification`.
  ///
  /// Returns `false` when there is no user or no Active Organization.
  public func checkAuthorization(role: String, reverification: ReverificationConfig? = nil) -> Bool {
    checkAuthorization(CheckAuthorizationParams(role: role, reverification: reverification))
  }

  /// Returns whether the user has `permission` in the Active Organization, and optionally
  /// reverified within `reverification`.
  ///
  /// Returns `false` when there is no user or no Active Organization.
  public func checkAuthorization(permission: String, reverification: ReverificationConfig? = nil) -> Bool {
    checkAuthorization(CheckAuthorizationParams(permission: permission, reverification: reverification))
  }

  /// Returns whether the user or Active Organization has the Billing `feature`, and optionally
  /// reverified within `reverification`.
  ///
  /// Prefix the slug with `user:` or `org:` to check one payer only. A Subscription change is
  /// reflected after the session token refreshes.
  public func checkAuthorization(feature: String, reverification: ReverificationConfig? = nil) -> Bool {
    checkAuthorization(CheckAuthorizationParams(feature: feature, reverification: reverification))
  }

  /// Returns whether the user or Active Organization is subscribed to the Billing `plan`, and
  /// optionally reverified within `reverification`.
  ///
  /// Prefix the slug with `user:` or `org:` to check one payer only. A Subscription change is
  /// reflected after the session token refreshes.
  public func checkAuthorization(plan: String, reverification: ReverificationConfig? = nil) -> Bool {
    checkAuthorization(CheckAuthorizationParams(plan: plan, reverification: reverification))
  }

  /// Returns whether the user reverified within `reverification`.
  public func checkAuthorization(reverification: ReverificationConfig) -> Bool {
    checkAuthorization(CheckAuthorizationParams(reverification: reverification))
  }

  func checkAuthorization(_ params: CheckAuthorizationParams) -> Bool {
    SessionAuthorization.evaluate(session: self, params: params)
  }
}

extension Clerk {
  /// Returns whether the signed-in user has `role` in the Active Organization. Returns `false` when
  /// no user is signed in or the session isn't active. See ``Session/checkAuthorization(role:reverification:)``.
  public func has(role: String, reverification: ReverificationConfig? = nil) -> Bool {
    activeSession?.checkAuthorization(role: role, reverification: reverification) ?? false
  }

  /// Returns whether the signed-in user has `permission` in the Active Organization. Returns `false`
  /// when no user is signed in or the session isn't active. See ``Session/checkAuthorization(permission:reverification:)``.
  public func has(permission: String, reverification: ReverificationConfig? = nil) -> Bool {
    activeSession?.checkAuthorization(permission: permission, reverification: reverification) ?? false
  }

  /// Returns whether the signed-in user or Active Organization has the Billing `feature`. Returns
  /// `false` when no user is signed in or the session isn't active. See ``Session/checkAuthorization(feature:reverification:)``.
  public func has(feature: String, reverification: ReverificationConfig? = nil) -> Bool {
    activeSession?.checkAuthorization(feature: feature, reverification: reverification) ?? false
  }

  /// Returns whether the signed-in user or Active Organization is subscribed to the Billing `plan`.
  /// Returns `false` when no user is signed in or the session isn't active. See ``Session/checkAuthorization(plan:reverification:)``.
  public func has(plan: String, reverification: ReverificationConfig? = nil) -> Bool {
    activeSession?.checkAuthorization(plan: plan, reverification: reverification) ?? false
  }

  /// Returns whether the signed-in user reverified within `reverification`. Returns `false` when no
  /// user is signed in or the session isn't active. See ``Session/checkAuthorization(reverification:)``.
  public func has(reverification: ReverificationConfig) -> Bool {
    activeSession?.checkAuthorization(reverification: reverification) ?? false
  }

  private var activeSession: Session? {
    guard let session, session.status == .active else { return nil }
    return session
  }
}
