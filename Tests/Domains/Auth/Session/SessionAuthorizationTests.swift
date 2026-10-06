@testable import ClerkKit
import Foundation
import Testing

struct SessionAuthorizationTests {
  @Test
  func checkAuthorizationOverloadsMatchTheCombinedEvaluator() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"],
      features: "o:reservations,u:dashboard",
      plans: "u:plus"
    )

    #expect(session.checkAuthorization(plan: "plus"))
    #expect(!session.checkAuthorization(plan: "missing"))
    #expect(session.checkAuthorization(feature: "org:reservations"))
    #expect(session.checkAuthorization(role: "org:admin"))
    #expect(session.checkAuthorization(permission: "org:sys_memberships:read"))
    #expect(!session.checkAuthorization(permission: "org:sys_profile:delete"))
    #expect(session.checkAuthorization(plan: "plus") == session.checkAuthorization(CheckAuthorizationParams(plan: "plus")))
    #expect(
      session.checkAuthorization(role: "org:admin", reverification: .strict)
        == session.checkAuthorization(CheckAuthorizationParams(role: "org:admin", reverification: .strict))
    )
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

    #expect(session.checkAuthorization(.init(feature: "o:reservations")))
    #expect(session.checkAuthorization(.init(feature: "org:reservations")))
    #expect(session.checkAuthorization(.init(feature: "organization:reservations")))
    #expect(session.checkAuthorization(.init(feature: "reservations")))
    #expect(session.checkAuthorization(.init(feature: "u:dashboard")))
    #expect(session.checkAuthorization(.init(feature: "user:dashboard")))
    #expect(session.checkAuthorization(.init(feature: "dashboard")))
    #expect(!session.checkAuthorization(.init(feature: "lol:dashboard")))
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
    #expect(!session.checkAuthorization(.init()))
  }

  @Test
  func failsPermissionAndRoleWhenOrgContextIsMissing() {
    let session = makeSession(orgId: nil, features: "", plans: "")
    #expect(!session.checkAuthorization(.init(permission: "org:sys_profile:delete", reverification: .strict)))
    #expect(!session.checkAuthorization(.init(role: "org:admin", reverification: .strict)))
  }

  @Test
  func failsReverificationWhenFactorVerificationAgeIsNil() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_profile:delete"],
      factorVerificationAge: nil
    )
    #expect(!session.checkAuthorization(.init(permission: "org:sys_profile:delete", reverification: .strict)))
  }

  @Test
  func failsWhenFactorVerificationAgePayloadIsMalformed() {
    let session = makeSession(factorVerificationAge: [0])
    #expect(!session.checkAuthorization(.init(reverification: .strictMfa)))
  }

  @Test
  func requiresAndAcrossBillingAndOrg() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"],
      features: "o:reservations"
    )
    #expect(!session.checkAuthorization(.init(permission: "org:sys_profile:delete", feature: "org:reservations")))
    #expect(session.checkAuthorization(.init(permission: "org:sys_memberships:read", feature: "org:reservations")))
  }

  @Test
  func requiresAndWithinOrgWhenRoleAndPermissionAreRequested() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"]
    )
    #expect(!session.checkAuthorization(.init(role: "org:admin", permission: "org:sys_profile:delete")))
    #expect(session.checkAuthorization(.init(role: "org:admin", permission: "org:sys_memberships:read")))
    #expect(!session.checkAuthorization(.init(role: "org:member", permission: "org:sys_memberships:read")))
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
    #expect(session.checkAuthorization(.init(feature: "org:reservations", plan: "u:plus")))
    #expect(!session.checkAuthorization(.init(feature: "org:reservations", plan: "u:free")))
    #expect(!session.checkAuthorization(.init(feature: "org:missing", plan: "u:plus")))
  }

  @Test
  func failsFeatureCheckWhenFeaturesClaimIsMissingOrEmpty() {
    let session = makeSession(orgId: "org_123", orgRole: "org:admin", orgPermissions: ["org:read"], features: "")
    #expect(!session.checkAuthorization(.init(feature: "org:premium")))
  }

  @Test
  func failsWhenTokenClaimsAreMissing() {
    var session = Session.mock
    session.user = user(id: "user_123", orgId: "org_123", role: "org:admin", permissions: ["org:read"])
    session.lastActiveOrganizationId = "org_123"
    session.lastActiveToken = nil
    #expect(!session.checkAuthorization(.init(feature: "reservations")))
    #expect(!session.checkAuthorization(.init(plan: "plus")))
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
    #expect(!session.checkAuthorization(.init(role: "org:admin", feature: "org:missing")))
    #expect(!session.checkAuthorization(.init(role: "org:admin", plan: "u:free")))
    #expect(session.checkAuthorization(.init(role: "org:admin", feature: "org:reservations")))
  }

  @Test
  func failsMissingFeaturesWhenReverificationWouldPass() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_profile:delete"],
      features: ""
    )
    #expect(!session.checkAuthorization(.init(feature: "org:premium", reverification: .strict)))
  }

  @Test
  func authorizesPermissionPlusReverificationWhenBothMatch() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"]
    )
    #expect(session.checkAuthorization(.init(permission: "org:sys_memberships:read", reverification: .strict)))
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
      session.checkAuthorization(
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
    #expect(session.checkAuthorization(.init(permission: "org:sys_memberships:read", reverification: .strictMfa)))
  }

  @Test
  func failsPermissionPlusReverificationWhenNoFactorsAreEnrolled() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"],
      factorVerificationAge: [-1, -1]
    )
    #expect(!session.checkAuthorization(.init(permission: "org:sys_memberships:read", reverification: .strict)))
  }

  @Test
  func failsReverificationWhenConfigObjectIsIncompleteOrOutOfRange() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_profile:delete"]
    )
    #expect(!session.checkAuthorization(.init(reverification: .custom(level: .multiFactor, afterMinutes: 0))))
    #expect(!session.checkAuthorization(.init(reverification: .custom(level: .multiFactor, afterMinutes: -1))))
    #expect(!session.checkAuthorization(.init(reverification: .custom(level: .unknown("nope"), afterMinutes: 10))))
  }

  @Test
  func failsClosedWithoutUserId() {
    var session = makeSession(features: "u:dashboard", plans: "u:plus")
    session.user = nil
    #expect(!session.checkAuthorization(.init(feature: "dashboard")))
    #expect(!session.checkAuthorization(.init(plan: "plus")))
    #expect(!session.checkAuthorization(.init(reverification: .strict)))
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
    #expect(session.checkAuthorization(.init(feature: "reservations")))
    #expect(session.checkAuthorization(.init(feature: "dashboard")))
    #expect(!session.checkAuthorization(.init(feature: "missing")))
  }

  @Test
  func orgScopedFeatureFailsWithoutActiveOrgClaim() {
    let session = makeSession(orgId: nil, features: "u:dashboard")
    #expect(!session.checkAuthorization(.init(feature: "o:dashboard")))
    #expect(session.checkAuthorization(.init(feature: "u:dashboard")))
  }

  @Test
  func roleCheckPrefixesOrg() {
    let session = makeSession(orgId: "org_123", orgRole: "admin", orgPermissions: ["org:sys_memberships:read"])
    #expect(session.checkAuthorization(.init(role: "org:admin")))
    #expect(session.checkAuthorization(.init(role: "admin")))
    #expect(!session.checkAuthorization(.init(role: "org:member")))
  }

  @Test
  func readsFeaAndPlaFromLastActiveToken() {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      features: "o:sso,u:dashboard",
      plans: "u:pro"
    )
    #expect(session.checkAuthorization(.init(feature: "sso")))
    #expect(session.checkAuthorization(.init(plan: "pro")))
    #expect(!session.checkAuthorization(.init(feature: "missing")))
    #expect(!session.checkAuthorization(.init(plan: "free")))
  }

  @Test
  func hasOnCachedTokenCostsLessThanTenTokenDecodes() throws {
    let session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"],
      features: "o:reservations,u:dashboard",
      plans: "u:plus"
    )
    let jwt = try #require(session.lastActiveToken?.jwt)
    let params = CheckAuthorizationParams(plan: "plus")
    #expect(session.checkAuthorization(params))

    let clock = ContinuousClock()
    var checks: [Duration] = []
    var decodes: [Duration] = []
    for _ in 0 ..< 1000 {
      checks.append(clock.measure { _ = session.checkAuthorization(params) })
      decodes.append(clock.measure { _ = try? DecodedJWT(jwt: jwt) })
    }
    let fastestCheck = try #require(checks.min())
    let fastestDecode = try #require(decodes.min())
    #expect(fastestCheck < fastestDecode * 10)
  }

  @Test
  func failsOrgScopedFeatureWhenSnapshotTokenBelongsToAnotherOrganization() {
    var session = makeSession(
      orgId: "org_b",
      orgRole: "org:admin",
      orgPermissions: ["org:read"],
      features: "o:feature_b"
    )
    session.lastActiveToken = TokenResource(
      jwt: jwtWithClaims(sid: session.id, orgId: "org_a", fea: "o:feature_a")
    )

    #expect(!session.checkAuthorization(.init(feature: "o:feature_a")))
    #expect(!session.checkAuthorization(.init(feature: "o:feature_b")))
  }

  @Test
  func failsStrictWhenMatchingTokenWithoutFvaAgesTheSessionSnapshot() {
    var session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"],
      factorVerificationAge: [0, 0]
    )
    session.lastActiveToken = TokenResource(
      jwt: jwtWithClaims(
        sid: session.id,
        orgId: "org_123",
        issuedAt: Int(Date().timeIntervalSince1970) - 11 * 60
      )
    )

    #expect(!session.checkAuthorization(.init(reverification: .strict)))
  }

  @Test
  func failsStrictWhenMatchingTokenFvaAgesPastTenMinutesWithoutClientRefresh() {
    var session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"],
      factorVerificationAge: [0, 0]
    )
    session.lastActiveToken = TokenResource(
      jwt: jwtWithClaims(
        sid: session.id,
        orgId: "org_123",
        fva: [0, 0],
        issuedAt: Int(Date().timeIntervalSince1970) - 11 * 60
      )
    )

    #expect(!session.checkAuthorization(.init(reverification: .strict)))
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
    session.lastActiveToken = TokenResource(
      jwt: jwtWithClaims(sid: session.id, orgId: orgId, fea: features, pla: plans)
    )
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

private func jwtWithClaims(
  sid: String,
  orgId: String? = nil,
  fea: String? = nil,
  pla: String? = nil,
  fva: [Int]? = nil,
  issuedAt: Int? = nil
) -> String {
  var claims: [String: Any] = ["sid": sid]
  if let orgId {
    claims["org_id"] = orgId
  }
  if let fea {
    claims["fea"] = fea
  }
  if let pla {
    claims["pla"] = pla
  }
  if let fva {
    claims["fva"] = fva
  }
  if let issuedAt {
    claims["iat"] = issuedAt
  }
  return try! testJWT(claims: claims)
}

@MainActor
@Suite(.serialized)
struct ClerkHasTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func returnsFalseWithoutASession() {
    Clerk.shared.client = nil
    defer { Clerk.shared.client = .mock }

    #expect(!Clerk.shared.has(role: "org:admin"))
    #expect(!Clerk.shared.has(permission: "org:sys_memberships:read"))
    #expect(!Clerk.shared.has(feature: "reservations"))
    #expect(!Clerk.shared.has(plan: "plus"))
    #expect(!Clerk.shared.has(reverification: .lax))
  }

  @Test
  func authorizesAnActiveSession() {
    setCurrentSession(status: .active)
    defer { Clerk.shared.client = .mock }

    #expect(Clerk.shared.has(plan: "plus"))
    #expect(Clerk.shared.has(feature: "dashboard"))
    #expect(Clerk.shared.has(role: "org:admin"))
    #expect(Clerk.shared.has(permission: "org:sys_memberships:read"))
    #expect(Clerk.shared.has(reverification: .lax))
  }

  @Test
  func returnsFalseForAPendingSession() throws {
    setCurrentSession(status: .pending)
    defer { Clerk.shared.client = .mock }

    let session = try #require(Clerk.shared.session)
    #expect(session.checkAuthorization(plan: "plus"))
    #expect(!Clerk.shared.has(plan: "plus"))
    #expect(!Clerk.shared.has(feature: "dashboard"))
    #expect(!Clerk.shared.has(role: "org:admin"))
    #expect(!Clerk.shared.has(permission: "org:sys_memberships:read"))
    #expect(!Clerk.shared.has(reverification: .lax))
  }

  private func setCurrentSession(status: Session.SessionStatus) {
    var session = makeSession(
      orgId: "org_123",
      orgRole: "org:admin",
      orgPermissions: ["org:sys_memberships:read"],
      features: "u:dashboard",
      plans: "u:plus"
    )
    session.status = status
    var client = Client.mock
    client.sessions = [session]
    client.lastActiveSessionId = session.id
    Clerk.shared.client = client
  }
}
