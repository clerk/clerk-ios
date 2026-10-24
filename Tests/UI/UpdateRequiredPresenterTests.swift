@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct UpdateRequiredPresenterTests {
  @Test
  func clerkKitFindsClerkKitUIPresenterByItsRegisteredName() {
    #expect(ClerkAutomaticPresenterLoader.load() is UpdateRequiredPresenter)
  }
}
