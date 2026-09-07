#if os(iOS) || os(macOS)

import ClerkJSCore
@_spi(FrameworkIntegration) import ClerkKit
import Testing

@MainActor
@Test func applyEngineClientJSONPublishesKitUser() throws {
  let clerk = Clerk()
  let data = try ClerkJSHost.snapshotSignedInClient()
  let payload = try FAPIJSON.normalizeClientJSON(data)
  try clerk.applyEngineClientJSON(payload, deviceToken: "js-client-jwt")
  #expect(clerk.user?.id == "user_fixture")
  #expect(clerk.session?.id == "sess_fixture")
  #expect(clerk.deviceToken == "js-client-jwt")
}

@MainActor
@Test func applyEngineEnvironmentJSONPublishesKitEnvironment() throws {
  let clerk = Clerk()
  let data = try ClerkJSHost.snapshotEnvironmentJSON()
  try clerk.applyEngineEnvironmentJSON(data)
  #expect(clerk.environment?.displayConfig.applicationName == "JSCore Cache")
}

#endif
