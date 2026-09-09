import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["fresh", "stale", "noSecondFactor", "noFactors", "missingAges"])
  func generatedAuthorizationUsesCanonicalSessionState(scenario: String) async throws {
    let host = try FixtureCapabilities(data: PackageProof.fixtureData())
    let ages: [Int]? = switch scenario {
    case "stale": [10, 10]
    case "noSecondFactor": [0, -1]
    case "noFactors": [-1, -1]
    case "missingAges": nil
    default: [0, 0]
    }
    let client = try authorizationClient(host, ages: ages)
    host.clientResponse = client
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let session = try #require(clerk.session)
    let before = host.requests.count
    #expect(session.factorVerificationAge == ages.map { SessionFactorVerificationAgeValue(item0: Double($0[0]), item1: Double($0[1])) })
    for role in ["admin", "org:admin"] {
      #expect(try await session.checkAuthorization(.case1(.init(role: role))))
    }
    #expect(try await !session.checkAuthorization(.case1(.init(role: "org:member"))))
    for feature in ["reservations", "o:reservations", "org:reservations", "organization:reservations", "dashboard", "u:dashboard", "user:dashboard", "o:support", "u:support", "o:billing", "u:billing"] {
      #expect(try await session.checkAuthorization(.case3(.init(feature: feature))))
    }
    #expect(try await !session.checkAuthorization(.case3(.init(feature: "lol:dashboard"))))
    #expect(try await session.checkAuthorization(.case4(.init(plan: "plus"))))
    #expect(try await !session.checkAuthorization(.case4(.init(plan: "free"))))
    #expect(try await !session.checkAuthorization(.case5(.init())))
    let permitted = CheckAuthorizationParams.case2(.init(permission: "org:read"))
    #expect(try await session.checkAuthorization(permitted))
    #expect(try await !session.checkAuthorization(.case2(.init(permission: "org:delete"))))
    let fresh = scenario == "fresh" || scenario == "noSecondFactor"
    #expect(try await session.checkAuthorization(.case2(.init(permission: "org:read", reverification: .case1("strict_mfa")))) == fresh)
    #expect(try await !session.checkAuthorization(.case3(.init(feature: "missing", reverification: .case2("strict")))))
    do {
      _ = try await session.checkAuthorization(.case5(.init(reverification: .case5(.init(level: .unrecognized("nope"), afterMinutes: 10)))))
      Issue.record("Unknown input levels must fail bridge validation")
    } catch let error as CoreError { #expect(error.code == "invalid_bridge_value") }
    #expect(host.requests.count == before)
    let updatedClient = try authorizationClient(host, ages: ages, permissions: [])
    let updated = try #require(updatedClient.object()["sessions"]?.array().first)
    host.clientResponse = updatedClient
    host.sessionReloadResponse = .object(["response": updated, "client": updatedClient])
    _ = try await session.reload()
    #expect(clerk.session?.id == session.id)
    #expect(try await !session.checkAuthorization(permitted))
  }
}

@MainActor private func authorizationClient(_ host: FixtureCapabilities, ages: [Int]?, permissions: [String] = ["org:read"]) throws -> JSONValue {
  var client = try host.fixtures["authenticatedClient"]!.object()
  var session = try client["sessions"]!.array()[0].object()
  var user = try session["user"]!.object()
  let membership = """
  {"object":"organization_membership","id":"orgmem_auth","role":"admin","role_name":"Admin","permissions":[],"public_metadata":{},"created_at":1700000000000,"updated_at":1700000000000,"organization":{"object":"organization","id":"org_auth","name":"Auth Org","slug":"auth-org","image_url":"","has_image":false,"public_metadata":{},"created_at":1700000000000,"updated_at":1700000000000}}
  """
  var member = try JSONDecoder().decode(JSONValue.self, from: Data(membership.utf8)).object()
  member["permissions"] = .array(permissions.map(JSONValue.string))
  user["organization_memberships"] = .array([.object(member)])
  session["user"] = .object(user)
  session["last_active_organization_id"] = .string("org_auth")
  session["factor_verification_age"] = ages.map { .array($0.map { .number(Double($0)) }) } ?? .null
  let now = Int(Date().timeIntervalSince1970)
  func encoded(_ value: String) -> String {
    Data(value.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
  }
  let token = encoded("{\"alg\":\"none\"}") + "." + encoded("{\"sid\":\"sess_native\",\"iat\":\(now),\"exp\":\(now + 3600),\"fea\":\"o:reservations,u:dashboard,ou:support,uo:billing\",\"pla\":\"u:plus\"}") + ".fixture"
  session["last_active_token"] = .object(["object": .string("token"), "jwt": .string(token)])
  client["sessions"] = .array([.object(session)])
  return .object(client)
}
