@testable import ClerkKit
import Foundation
import Testing

struct SessionLifetimeTests {
  @Test
  func zeroDeadlinesDecodeAsUnixEpoch() throws {
    let session = try sessionWithZeroDeadlines(status: "active")
    #expect(session.expireAt == Date(timeIntervalSince1970: 0))
    #expect(session.abandonAt == Date(timeIntervalSince1970: 0))
    #expect(session.status == .active)
  }

  @Test
  func revokedSessionKeepsZeroDeadlines() throws {
    let session = try sessionWithZeroDeadlines(status: "revoked")
    #expect(session.expireAt == Date(timeIntervalSince1970: 0))
    #expect(session.abandonAt == Date(timeIntervalSince1970: 0))
    #expect(session.status == .revoked)
  }

  @Test
  func zeroDeadlinesSurviveClientCacheRoundTrip() throws {
    let session = try sessionWithZeroDeadlines(status: "active")
    let encoded = try JSONEncoder.clerkEncoder.encode(session)
    let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(json["expire_at"] as? Int == 0)
    #expect(json["abandon_at"] as? Int == 0)
    let restored = try JSONDecoder.clerkDecoder.decode(Session.self, from: encoded)
    #expect(restored == session)
    #expect(restored.expireAt == Date(timeIntervalSince1970: 0))
    #expect(restored.abandonAt == Date(timeIntervalSince1970: 0))
  }

  private func sessionWithZeroDeadlines(status: String) throws -> Session {
    let json = """
    {"id":"sess_native","status":"\(status)","expire_at":0,"abandon_at":0,"last_active_at":1,"created_at":1,"updated_at":1}
    """
    return try JSONDecoder.clerkDecoder.decode(Session.self, from: Data(json.utf8))
  }
}
