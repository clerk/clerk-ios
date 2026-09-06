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

  @Test
  func encodeThenApplyRoundTripsUnsignedClient() throws {
    let url = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let data = try Data(contentsOf: url)
    var source = WatchCompanion()
    try source.apply([WatchCompanion.clientKey: data])

    var replica = WatchCompanion()
    try replica.apply(source.encode())
    #expect(replica.client?.id == "client_fixture")
  }

  @Test
  func encodeOmitsMissingKeysAndApplyLeavesReplicaAsIs() throws {
    let url = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let data = try Data(contentsOf: url)
    var replica = WatchCompanion()
    try replica.apply([WatchCompanion.clientKey: data])

    let emptyPayload = try WatchCompanion().encode()
    #expect(!emptyPayload.keys.contains(WatchCompanion.clientKey))
    #expect(!emptyPayload.keys.contains(WatchCompanion.environmentKey))

    try replica.apply(emptyPayload)
    #expect(replica.client?.id == "client_fixture")
  }
}
