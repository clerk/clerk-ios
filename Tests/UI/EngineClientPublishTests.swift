#if os(iOS) || os(macOS)

@_spi(FrameworkIntegration) import ClerkKit
import Testing

@MainActor
@Test func signedInPreviewPublishesKitUser() {
  let clerk = Clerk()
  ClerkJSHostStore.registerPreview(isSignedIn: true, publishableKey: "", onto: clerk)
  #expect(clerk.user?.id == "user_fixture")
  #expect(clerk.session?.id == "sess_fixture")
}

@MainActor
@Test func signedOutPreviewPublishesEnvironmentWithoutAUser() {
  let clerk = Clerk()
  ClerkJSHostStore.registerPreview(isSignedIn: false, publishableKey: "", onto: clerk)
  #expect(clerk.environment?.displayConfig.applicationName == "JSCore Cache")
  #expect(clerk.user == nil)
}

#endif
