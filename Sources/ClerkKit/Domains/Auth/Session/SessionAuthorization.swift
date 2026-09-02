//
//  SessionAuthorization.swift
//

import Foundation

/// Parameters for ``Session/checkAuthorization(_:)`` and ``Session/has(_:)``.
///
/// Matches clerk-js `CheckAuthorizationParams`. The public TypeScript type treats role, permission,
/// feature, and plan as mutually exclusive. The runtime combiner still ANDs every dimension that is
/// present, including feature + plan.
public struct CheckAuthorizationParams: Sendable, Equatable {
  public var role: String?
  public var permission: String?
  public var feature: String?
  public var plan: String?
  public var reverification: ReverificationConfig?

  public init(
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

/// Reverification requirement for ``Session/checkAuthorization(_:)``.
///
/// Matches clerk-js `ReverificationConfig`: presets `strict_mfa`, `strict`, `moderate`, `lax`, or a
/// custom `{ level, afterMinutes }` object.
public enum ReverificationConfig: Sendable, Equatable {
  case strictMfa
  case strict
  case moderate
  case lax
  case custom(level: SessionVerification.Level, afterMinutes: Int)
}

extension Session {
  /// Checks whether this session is authorized for the requested role, permission, feature, plan,
  /// and/or reverification.
  ///
  /// Shares one implementation with ``has(_:)``. Returns `false` when the user is missing or any
  /// requested dimension fails. Org role and permission come from the active organization
  /// membership. Feature and plan come from the last active session token `fea` / `pla` claims.
  public func checkAuthorization(_ params: CheckAuthorizationParams) -> Bool {
    SessionAuthorization.evaluate(session: self, params: params)
  }

  /// Alias for ``checkAuthorization(_:)``. Matches the `useAuth().has` / `auth().has` name.
  public func has(_ params: CheckAuthorizationParams) -> Bool {
    checkAuthorization(params)
  }
}

enum SessionAuthorization {
  private enum CheckResult {
    case pass
    case fail
    case skip
  }

  private static let orgScopes: Set<String> = ["o", "org", "organization"]
  private static let userScopes: Set<String> = ["u", "user"]
  private static let allowedLevels: Set<String> = ["first_factor", "second_factor", "multi_factor"]

  static func evaluate(session: Session, params: CheckAuthorizationParams) -> Bool {
    let membership = session.user?.organizationMemberships?.first {
      $0.organization.id == session.lastActiveOrganizationId
    }
    return evaluate(
      userId: session.user?.id,
      orgId: membership?.organization.id,
      orgRole: membership?.role,
      orgPermissions: membership?.permissions,
      factorVerificationAge: session.factorVerificationAge,
      features: session.lastActiveToken?.featuresClaim ?? "",
      plans: session.lastActiveToken?.plansClaim ?? "",
      params: params
    )
  }

  static func evaluate(
    userId: String?,
    orgId: String?,
    orgRole: String?,
    orgPermissions: [String]?,
    factorVerificationAge: [Int]?,
    features: String?,
    plans: String?,
    params: CheckAuthorizationParams
  ) -> Bool {
    guard let userId, !userId.isEmpty else {
      return false
    }

    return combine([
      checkOrgAuthorization(
        role: params.role,
        permission: params.permission,
        orgId: orgId,
        orgRole: orgRole,
        orgPermissions: orgPermissions
      ),
      checkBillingAuthorization(
        feature: params.feature,
        plan: params.plan,
        features: features,
        plans: plans
      ),
      checkReverificationAuthorization(
        reverification: params.reverification,
        factorVerificationAge: factorVerificationAge
      ),
    ])
  }

  static func splitByScope(_ claim: String?) throws -> (org: [String], user: [String]) {
    var org: [String] = []
    var user: [String] = []

    guard let claim, !claim.isEmpty else {
      return (org, user)
    }

    for part in claim.split(separator: ",", omittingEmptySubsequences: false) {
      let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
      guard let colonIndex = trimmed.firstIndex(of: ":") else {
        throw SessionAuthorizationError.invalidClaimElement(trimmed)
      }
      let scope = String(trimmed[..<colonIndex])
      let value = String(trimmed[trimmed.index(after: colonIndex)...])
      switch scope {
      case "o":
        org.append(value)
      case "u":
        user.append(value)
      case "ou", "uo":
        org.append(value)
        user.append(value)
      default:
        break
      }
    }

    return (org, user)
  }

  private static func combine(_ results: [CheckResult]) -> Bool {
    results.contains(.pass) && results.allSatisfy { $0 == .pass || $0 == .skip }
  }

  private static func prefixWithOrg(_ value: String) -> String {
    let stripped = value.replacingOccurrences(of: "^(org:)*", with: "", options: .regularExpression)
    return "org:\(stripped)"
  }

  private static func checkOrgAuthorization(
    role: String?,
    permission: String?,
    orgId: String?,
    orgRole: String?,
    orgPermissions: [String]?
  ) -> CheckResult {
    let roleAsked = role != nil
    let permissionAsked = permission != nil

    if !roleAsked, !permissionAsked {
      return .skip
    }

    guard let orgId, !orgId.isEmpty else {
      return .fail
    }

    if roleAsked {
      guard let role, let orgRole, !orgRole.isEmpty, prefixWithOrg(orgRole) == prefixWithOrg(role) else {
        return .fail
      }
    }

    if permissionAsked {
      guard let permission, let orgPermissions, orgPermissions.contains(prefixWithOrg(permission)) else {
        return .fail
      }
    }

    return .pass
  }

  private static func checkBillingAuthorization(
    feature: String?,
    plan: String?,
    features: String?,
    plans: String?
  ) -> CheckResult {
    let featureAsked = feature != nil
    let planAsked = plan != nil

    if !featureAsked, !planAsked {
      return .skip
    }

    if featureAsked {
      guard let feature, let features, !features.isEmpty else {
        return .fail
      }
      do {
        if try !checkForFeatureOrPlan(claim: features, featureOrPlan: feature) {
          return .fail
        }
      } catch {
        return .fail
      }
    }

    if planAsked {
      guard let plan, let plans, !plans.isEmpty else {
        return .fail
      }
      do {
        if try !checkForFeatureOrPlan(claim: plans, featureOrPlan: plan) {
          return .fail
        }
      } catch {
        return .fail
      }
    }

    return .pass
  }

  private static func checkForFeatureOrPlan(claim: String, featureOrPlan: String) throws -> Bool {
    let split = try splitByScope(claim)
    let parts = featureOrPlan.split(separator: ":", omittingEmptySubsequences: false)
    let rawScope = String(parts[0])
    let hasExplicitScope = parts.count > 1
    let id = hasExplicitScope ? String(parts[1]) : rawScope

    if hasExplicitScope, !orgScopes.contains(rawScope), !userScopes.contains(rawScope) {
      throw SessionAuthorizationError.invalidScope(rawScope)
    }

    if hasExplicitScope {
      if orgScopes.contains(rawScope) {
        return split.org.contains(id)
      }
      if userScopes.contains(rawScope) {
        return split.user.contains(id)
      }
    }

    return (split.org + split.user).contains(id)
  }

  private static func checkReverificationAuthorization(
    reverification: ReverificationConfig?,
    factorVerificationAge: [Int]?
  ) -> CheckResult {
    guard let reverification else {
      return .skip
    }

    guard let factorVerificationAge else {
      return .fail
    }

    guard
      factorVerificationAge.count == 2,
      isValidFactorAge(factorVerificationAge[0]),
      isValidFactorAge(factorVerificationAge[1])
    else {
      return .fail
    }

    guard let resolved = resolveReverification(reverification) else {
      return .fail
    }

    let factor1Age = factorVerificationAge[0]
    let factor2Age = factorVerificationAge[1]
    let afterMinutes = resolved.afterMinutes

    if factor1Age == -1, factor2Age == -1 {
      return .fail
    }

    let factor1FreshEnough = factor1Age != -1 && afterMinutes > factor1Age
    let factor2FreshEnough = factor2Age != -1 && afterMinutes > factor2Age

    switch resolved.level {
    case .firstFactor:
      return factor1FreshEnough ? .pass : .fail
    case .secondFactor:
      if factor2Age == -1 {
        return factor1FreshEnough ? .pass : .fail
      }
      if factor1Age == -1 {
        return factor2FreshEnough ? .pass : .fail
      }
      return factor2FreshEnough ? .pass : .fail
    case .multiFactor:
      if factor2Age == -1 {
        return factor1FreshEnough ? .pass : .fail
      }
      if factor1Age == -1 {
        return .fail
      }
      return factor1FreshEnough && factor2FreshEnough ? .pass : .fail
    case .unknown:
      return .fail
    }
  }

  private static func resolveReverification(
    _ config: ReverificationConfig
  ) -> (level: SessionVerification.Level, afterMinutes: Int)? {
    switch config {
    case .strictMfa:
      return (.multiFactor, 10)
    case .strict:
      return (.secondFactor, 10)
    case .moderate:
      return (.secondFactor, 60)
    case .lax:
      return (.secondFactor, 1440)
    case .custom(let level, let afterMinutes):
      guard allowedLevels.contains(level.rawValue), afterMinutes > 0 else {
        return nil
      }
      return (level, afterMinutes)
    }
  }

  private static func isValidFactorAge(_ value: Int) -> Bool {
    value == -1 || value >= 0
  }
}

private enum SessionAuthorizationError: Error {
  case invalidClaimElement(String)
  case invalidScope(String)
}
