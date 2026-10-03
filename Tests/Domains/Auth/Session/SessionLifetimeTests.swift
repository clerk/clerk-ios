@testable import ClerkKit
import Foundation
import Testing

struct SessionLifetimeTests {
  @Test
  func indefiniteLifetimeSurvivesSerialization() throws {
    let json = """
    {"id":"sess_native","status":"active","expire_at":0,"abandon_at":0,"last_active_at":1,"created_at":1,"updated_at":1}
    """
    let session = try JSONDecoder.clerkDecoder.decode(Session.self, from: Data(json.utf8))
    #expect(!session.hasMaximumLifetime)
    #expect(session.expireAt == Date(timeIntervalSince1970: 0))
    #expect(session.abandonAt == Date(timeIntervalSince1970: 0))
    #expect(session.status == .active)
    let encoded = try JSONEncoder().encode(session)
    let restored = try JSONDecoder().decode(Session.self, from: encoded)
    #expect(restored == session)
    var finite = session
    finite.expireAt = Date(timeIntervalSince1970: 2_000_000_000)
    #expect(finite.hasMaximumLifetime)
  }
}
