@testable import ClerkKit
import Foundation
import Testing

struct SessionLifetimeTests {
  @Test
  func zeroExpireAtHasNoMaximumLifetime() throws {
    #expect(try !indefiniteSession().hasMaximumLifetime)
  }

  @Test
  func futureExpireAtHasMaximumLifetime() throws {
    var session = try indefiniteSession()
    session.expireAt = Date(timeIntervalSince1970: 2_000_000_000)
    #expect(session.hasMaximumLifetime)
  }

  @Test
  func revokedSessionWithZeroExpireAtHasNoMaximumLifetime() throws {
    var session = try indefiniteSession()
    session.status = .revoked
    #expect(!session.hasMaximumLifetime)
  }

  @Test
  func zeroDeadlinesDecodeAsUnixEpoch() throws {
    let session = try indefiniteSession()
    #expect(session.expireAt == Date(timeIntervalSince1970: 0))
    #expect(session.abandonAt == Date(timeIntervalSince1970: 0))
    #expect(session.status == .active)
  }

  @Test
  func indefiniteSessionSurvivesClientCacheRoundTrip() throws {
    let session = try indefiniteSession()
    let encoded = try JSONEncoder.clerkEncoder.encode(session)
    let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(json["expire_at"] as? Int == 0)
    #expect(json["abandon_at"] as? Int == 0)
    let restored = try JSONDecoder.clerkDecoder.decode(Session.self, from: encoded)
    #expect(restored == session)
    #expect(!restored.hasMaximumLifetime)
  }

  @Test
  func indefiniteSessionSurvivesDefaultCodableRoundTrip() throws {
    let session = try indefiniteSession()
    let restored = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))
    #expect(restored == session)
    #expect(!restored.hasMaximumLifetime)
  }

  private func indefiniteSession() throws -> Session {
    let json = """
    {"id":"sess_native","status":"active","expire_at":0,"abandon_at":0,"last_active_at":1,"created_at":1,"updated_at":1}
    """
    return try JSONDecoder.clerkDecoder.decode(Session.self, from: Data(json.utf8))
  }
}
