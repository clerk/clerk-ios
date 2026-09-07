#if os(iOS) || os(macOS)

import ClerkJSCore
import ClerkKit
import Testing

@MainActor
@Test func applyEngineClientJSONPublishesKitUser() throws {
  let clerk = Clerk()
  let data = try ClerkJSCore.Clerk.snapshotSignedInClient()
  let payload = try FAPIJSON.normalizeClientJSON(data)
  try clerk.applyEngineClientJSON(payload)
  #expect(clerk.user?.id == "user_fixture")
  #expect(clerk.session?.id == "sess_fixture")
}

@MainActor
@Test func applyEngineEnvironmentJSONPublishesKitEnvironment() throws {
  let clerk = Clerk()
  let data = try ClerkJSCore.Clerk.snapshotEnvironmentJSON()
  try clerk.applyEngineEnvironmentJSON(data)
  #expect(clerk.environment?.displayConfig.applicationName == "JSCore Cache")
}

#endif
