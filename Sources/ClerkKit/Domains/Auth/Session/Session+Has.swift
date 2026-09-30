//
//  Session+Has.swift
//

import Foundation

/// The conditions evaluated by ``Session/has(role:reverification:)`` and its overloads.
///
/// Matches clerk-js `CheckAuthorizationParams`. The public overloads accept one of role,
/// permission, feature, or plan, each optionally combined with reverification. The evaluator still
/// ANDs every dimension that is present.
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

/// Reverification requirement for ``Session/has(reverification:)``.
///
/// Matches clerk-js `ReverificationConfig`: presets `strict_mfa`, `strict`, `moderate`, `lax`, or a
/// custom `{ level, afterMinutes }` object.
public enum ReverificationConfig: Sendable, Equatable {
  /// Multi-factor verification within the last 10 minutes.
  case strictMfa
  /// Second-factor verification within the last 10 minutes.
  case strict
  /// Second-factor verification within the last hour.
  case moderate
  /// Second-factor verification within the last day.
  case lax
  /// Verification at `level` within the last `afterMinutes` minutes.
  case custom(level: SessionVerification.Level, afterMinutes: Int)
}

extension Session {
  /// Returns whether the user has `role` in the Active Organization, and optionally reverified
  /// within `reverification`.
  ///
  /// Returns `false` when there is no user or no Active Organization.
  public func has(role: String, reverification: ReverificationConfig? = nil) -> Bool {
    has(CheckAuthorizationParams(role: role, reverification: reverification))
  }

  /// Returns whether the user has `permission` in the Active Organization, and optionally
  /// reverified within `reverification`.
  ///
  /// Returns `false` when there is no user or no Active Organization.
  public func has(permission: String, reverification: ReverificationConfig? = nil) -> Bool {
    has(CheckAuthorizationParams(permission: permission, reverification: reverification))
  }

  /// Returns whether the user or Active Organization has the Billing `feature`, and optionally
  /// reverified within `reverification`.
  ///
  /// Prefix the slug with `user:` or `org:` to check one payer only. Reads the session token's
  /// `fea` claim, so a Subscription change is reflected after the token refreshes.
  public func has(feature: String, reverification: ReverificationConfig? = nil) -> Bool {
    has(CheckAuthorizationParams(feature: feature, reverification: reverification))
  }

  /// Returns whether the user or Active Organization is subscribed to the Billing `plan`, and
  /// optionally reverified within `reverification`.
  ///
  /// Prefix the slug with `user:` or `org:` to check one payer only. Reads the session token's
  /// `pla` claim, so a Subscription change is reflected after the token refreshes.
  public func has(plan: String, reverification: ReverificationConfig? = nil) -> Bool {
    has(CheckAuthorizationParams(plan: plan, reverification: reverification))
  }

  /// Returns whether the user reverified within `reverification`.
  public func has(reverification: ReverificationConfig) -> Bool {
    has(CheckAuthorizationParams(reverification: reverification))
  }

  func has(_ params: CheckAuthorizationParams) -> Bool {
    SessionAuthorization.evaluate(session: self, params: params)
  }
}

extension Clerk {
  /// Returns whether the signed-in user has `role` in the Active Organization. Returns `false` when
  /// no user is signed in. See ``Session/has(role:reverification:)``.
  public func has(role: String, reverification: ReverificationConfig? = nil) -> Bool {
    session?.has(role: role, reverification: reverification) ?? false
  }

  /// Returns whether the signed-in user has `permission` in the Active Organization. Returns `false`
  /// when no user is signed in. See ``Session/has(permission:reverification:)``.
  public func has(permission: String, reverification: ReverificationConfig? = nil) -> Bool {
    session?.has(permission: permission, reverification: reverification) ?? false
  }

  /// Returns whether the signed-in user or Active Organization has the Billing `feature`. Returns
  /// `false` when no user is signed in. See ``Session/has(feature:reverification:)``.
  public func has(feature: String, reverification: ReverificationConfig? = nil) -> Bool {
    session?.has(feature: feature, reverification: reverification) ?? false
  }

  /// Returns whether the signed-in user or Active Organization is subscribed to the Billing `plan`.
  /// Returns `false` when no user is signed in. See ``Session/has(plan:reverification:)``.
  public func has(plan: String, reverification: ReverificationConfig? = nil) -> Bool {
    session?.has(plan: plan, reverification: reverification) ?? false
  }

  /// Returns whether the signed-in user reverified within `reverification`. Returns `false` when no
  /// user is signed in. See ``Session/has(reverification:)``.
  public func has(reverification: ReverificationConfig) -> Bool {
    session?.has(reverification: reverification) ?? false
  }
}
