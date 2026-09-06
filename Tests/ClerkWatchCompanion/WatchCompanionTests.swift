import ClerkWatchCompanion
import Foundation
import Testing

struct WatchCompanionTests {
  @Test
  func applyDecodesUnsignedClientFromWatchPayload() throws {
    let url = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let data = try Data(contentsOf: url)
    var replica = WatchCompanion()
    try replica.apply([WatchCompanion.clientKey: data])
    #expect(replica.client?.id == "client_fixture")
  }
}
