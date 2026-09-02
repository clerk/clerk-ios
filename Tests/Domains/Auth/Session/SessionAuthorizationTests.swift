@testable import ClerkKit
import Foundation
import Testing

struct SessionAuthorizationTests {
  @Test
  func checkAuthorizationAndHasShareOneImplementation() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"],
      features: "o:reservations,u:dashboard",
      plans: "u:plus"
    )

    let params = CheckAuthorizationParams(plan: "plus")
    #expect(session.has(params) == session.checkAuthorization(params))
    #expect(session.has(params) == true)
    #expect(session.has(.init(plan: "missing")) == session.checkAuthorization(.init(plan: "missing")))
    #expect(session.has(.init(plan: "missing")) == false)
  }

  @Test
  func decodesFactorVerificationAge() throws {
    let json = """
    {
      "id": "sess_1",
      "status": "active",
      "expire_at": 1000,
      "abandon_at": 1000,
      "last_active_at": 1000,
      "created_at": 1000,
      "updated_at": 1000,
      "factor_verification_age": [5, 10]
    }
    """
    let session = try JSONDecoder.clerkDecoder.decode(Session.self, from: Data(json.utf8))
    #expect(session.factorVerificationAge == [5, 10])
  }

  @Test
  func missingFactorVerificationAgeDecodesAsNil() throws {
    let json = """
    {
      "id": "sess_1",
      "status": "active",
      "expire_at": 1000,
      "abandon_at": 1000,
      "last_active_at": 1000,
      "created_at": 1000,
      "updated_at": 1000
    }
    """
    let session = try JSONDecoder.clerkDecoder.decode(Session.self, from: Data(json.utf8))
    #expect(session.factorVerificationAge == nil)
  }

  @Test
  func parsesFeaturesByScope() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "admin",
      orgPermissions: ["org:read"],
      features: "o:reservations,u:dashboard"
    )

    #expect(session.has(.init(feature: "o:reservations")))
    #expect(session.has(.init(feature: "org:reservations")))
    #expect(session.has(.init(feature: "organization:reservations")))
    #expect(session.has(.init(feature: "reservations")))
    #expect(session.has(.init(feature: "u:dashboard")))
    #expect(session.has(.init(feature: "user:dashboard")))
    #expect(session.has(.init(feature: "dashboard")))
    #expect(!session.has(.init(feature: "lol:dashboard")))
  }

  @Test
  func failsWhenNoDimensionWasRequested() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_profile:delete"],
      features: "o:premium",
      plans: "plus"
    )
    #expect(!session.has(.init()))
  }

  @Test
  func failsPermissionAndRoleWhenOrgContextIsMissing() {
    let session = makeSession(orgId: nil, features: "", plans: "")
    #expect(!session.has(.init(permission: "org:sys_profile:delete", reverification: .strict)))
    #expect(!session.has(.init(role: "org:admin", reverification: .strict)))
  }

  @Test
  func failsReverificationWhenFactorVerificationAgeIsNil() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_profile:delete"],
      factorVerificationAge: nil
    )
    #expect(!session.has(.init(permission: "org:sys_profile:delete", reverification: .strict)))
  }

  @Test
  func failsWhenFactorVerificationAgePayloadIsMalformed() {
    let session = makeSession(factorVerificationAge: [0])
    #expect(!session.has(.init(reverification: .strictMfa)))
  }

  @Test
  func requiresAndAcrossBillingAndOrg() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"],
      features: "o:reservations"
    )
    #expect(!session.has(.init(permission: "org:sys_profile:delete", feature: "org:reservations")))
    #expect(session.has(.init(permission: "org:sys_memberships:read", feature: "org:reservations")))
  }

  @Test
  func requiresAndWithinOrgWhenRoleAndPermissionAreRequested() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"]
    )
    #expect(!session.has(.init(role: "org:admin", permission: "org:sys_profile:delete")))
    #expect(session.has(.init(role: "org:admin", permission: "org:sys_memberships:read")))
    #expect(!session.has(.init(role: "org:member", permission: "org:sys_memberships:read")))
  }

  @Test
  func requiresAndWithinBillingWhenFeatureAndPlanAreRequested() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:read"],
      features: "o:reservations",
      plans: "u:plus"
    )
    #expect(session.has(.init(feature: "org:reservations", plan: "u:plus")))
    #expect(!session.has(.init(feature: "org:reservations", plan: "u:free")))
    #expect(!session.has(.init(feature: "org:missing", plan: "u:plus")))
  }

  @Test
  func failsFeatureCheckWhenFeaturesClaimIsMissingOrEmpty() {
    let session = makeSession(orgId: "org_123", orgRole: "org:admin", orgPermissions: ["org:read"], features: "")
    #expect(!session.has(.init(feature: "org:premium")))
  }

  @Test
  func failsWhenTokenClaimsAreMissing() {
    var session = Session.mock
    session.user = user(id: "user_123", orgId: "org_123", role: "org:admin", permissions: ["org:read"])
    session.lastActiveOrganizationId = "org_123"
    session.lastActiveToken = nil
    #expect(!session.has(.init(feature: "reservations")))
    #expect(!session.has(.init(plan: "plus")))
  }

  @Test
  func requiresAndAcrossOrgAndBillingCombos() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"],
      features: "o:reservations",
      plans: "u:plus"
    )
    #expect(!session.has(.init(role: "org:admin", feature: "org:missing")))
    #expect(!session.has(.init(role: "org:admin", plan: "u:free")))
    #expect(session.has(.init(role: "org:admin", feature: "org:reservations")))
  }

  @Test
  func failsMissingFeaturesWhenReverificationWouldPass() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_profile:delete"],
      features: ""
    )
    #expect(!session.has(.init(feature: "org:premium", reverification: .strict)))
  }

  @Test
  func authorizesPermissionPlusReverificationWhenBothMatch() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"]
    )
    #expect(session.has(.init(permission: "org:sys_memberships:read", reverification: .strict)))
  }

  @Test
  func authorizesEveryRequestedDimensionWhenAllThreeMatch() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"],
      features: "o:reservations"
    )
    #expect(
      session.has(
        .init(
          permission: "org:sys_memberships:read",
          feature: "org:reservations",
          reverification: .strict
        )
      )
    )
  }

  @Test
  func authorizesStrictMfaViaGracefulDowngradeWhenNoSecondFactorIsEnrolled() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"],
      factorVerificationAge: [0, -1]
    )
    #expect(session.has(.init(permission: "org:sys_memberships:read", reverification: .strictMfa)))
  }

  @Test
  func failsPermissionPlusReverificationWhenNoFactorsAreEnrolled() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"],
      factorVerificationAge: [-1, -1]
    )
    #expect(!session.has(.init(permission: "org:sys_memberships:read", reverification: .strict)))
  }

  @Test
  func failsReverificationWhenConfigObjectIsIncompleteOrOutOfRange() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_profile:delete"]
    )
    #expect(!session.has(.init(reverification: .custom(level: .multiFactor, afterMinutes: 0))))
    #expect(!session.has(.init(reverification: .custom(level: .multiFactor, afterMinutes: -1))))
    #expect(!session.has(.init(reverification: .custom(level: .unknown("nope"), afterMinutes: 10))))
  }

  @Test
  func failsClosedWithoutUserId() {
    var session = makeSession(features: "u:dashboard", plans: "u:plus")
    session.user = nil
    #expect(!session.has(.init(feature: "dashboard")))
    #expect(!session.has(.init(plan: "plus")))
    #expect(!session.has(.init(reverification: .strict)))
  }

  @Test
  func splitsFeaturesByScopeIncludingMergedOuAndUo() throws {
    let split = try SessionAuthorization.splitByScope("o:reservations,u:dashboard,ou:support-chat,uo:billing")
    #expect(split.org == ["reservations", "support-chat", "billing"])
    #expect(split.user == ["dashboard", "support-chat", "billing"])
  }

  @Test
  func splitByScopeThrowsWhenClaimElementIsMissingAColon() {
    #expect(throws: Error.self) {
      try SessionAuthorization.splitByScope("reservations,dashboard")
    }
  }

  @Test
  func unscopedFeatureMatchesMergedUserAndOrgIds() {
    let session = makeSession(orgId: "org_123", orgRole: "org:admin", features: "o:reservations,u:dashboard")
    #expect(session.has(.init(feature: "reservations")))
    #expect(session.has(.init(feature: "dashboard")))
    #expect(!session.has(.init(feature: "missing")))
  }

  @Test
  func orgScopedFeatureFailsWithoutActiveOrgClaim() {
    let session = makeSession(orgId: nil, features: "u:dashboard")
    #expect(!session.has(.init(feature: "o:dashboard")))
    #expect(session.has(.init(feature: "u:dashboard")))
  }

  @Test
  func roleCheckPrefixesOrg() {
    let session = makeSession(orgId: "org_123", orgRole: "admin", orgPermissions: ["org:sys_memberships:read"])
    #expect(session.has(.init(role: "org:admin")))
    #expect(session.has(.init(role: "admin")))
    #expect(!session.has(.init(role: "org:member")))
  }

  @Test
  func readsFeaAndPlaFromLastActiveToken() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      features: "o:sso,u:dashboard",
      plans: "u:pro"
    )
    #expect(session.has(.init(feature: "sso")))
    #expect(session.has(.init(plan: "pro")))
    #expect(!session.has(.init(feature: "missing")))
    #expect(!session.has(.init(plan: "free")))
  }
}

private func makeSession(
  userId: String = "user_123",
  orgId: String? = nil,
  orgRole: String? = nil,
  orgPermissions: [String]? = nil,
  features: String? = nil,
  plans: String? = nil,
  factorVerificationAge: [Int]? = [0, 0]
) -> Session {
  var session = Session.mock
  session.user = user(id: userId, orgId: orgId, role: orgRole, permissions: orgPermissions)
  session.lastActiveOrganizationId = orgId
  session.factorVerificationAge = factorVerificationAge
  if features != nil || plans != nil {
    session.lastActiveToken = TokenResource(jwt: jwtWithClaims(fea: features, pla: plans))
  }
  return session
}

private func user(
  id: String,
  orgId: String?,
  role: String?,
  permissions: [String]?
) -> User {
  var user = User.mock
  user.id = id
  if let orgId {
    var membership = OrganizationMembership.mockWithUserData
    membership.role = role ?? "org:member"
    membership.permissions = permissions
    var organization = membership.organization
    organization.id = orgId
    membership.organization = organization
    user.organizationMemberships = [membership]
  } else {
    user.organizationMemberships = []
  }
  return user
}

private func jwtWithClaims(fea: String?, pla: String?) -> String {
  var payload: [String: String] = [:]
  if let fea {
    payload["fea"] = fea
  }
  if let pla {
    payload["pla"] = pla
  }
  return encodeJWT(payload: payload)
}

private func encodeJWT(payload: [String: String]) -> String {
  func encode(_ object: [String: String]) -> String {
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .trimmingCharacters(in: CharacterSet(charactersIn: "="))
  }
  return "\(encode(["alg": "none", "typ": "JWT"])).\(encode(payload)).sig"
}
