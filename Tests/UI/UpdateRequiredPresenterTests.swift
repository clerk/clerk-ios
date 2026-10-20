@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct UpdateRequiredPresenterTests {
  @Test
  func clerkKitFindsClerkKitUIPresenterByItsRegisteredName() {
    #if os(iOS)
    #expect(ClerkAutomaticPresenterLoader.load() is UpdateRequiredPresenter)
    #else
    #expect(ClerkAutomaticPresenterLoader.load() == nil)
    #endif
  }
}
