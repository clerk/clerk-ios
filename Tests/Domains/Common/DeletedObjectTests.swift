@testable import ClerkKit
import Foundation
import Testing

struct DeletedObjectTests {
  @Test
  func decodesJSDeletePayloadWithoutObject() throws {
    let data = Data(#"{"id":"user_1","deleted":true}"#.utf8)
    let deleted = try JSONDecoder.clerkDecoder.decode(DeletedObject.self, from: data)
    #expect(deleted.id == "user_1")
    #expect(deleted.deleted == true)
    #expect(deleted.object == "deleted_object")
  }
}
