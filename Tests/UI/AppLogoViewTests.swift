import ClerkJSCore
@testable import ClerkKit
@testable import ClerkKitUI
import SwiftUI
import Testing

@MainActor
struct AppLogoViewTests {
  @Test
  func customAppIconViewOwnsItsLayout() {
    let renderer = ImageRenderer(
      content: AppLogoView()
        .environment(ClerkKit.Clerk.mock)
        .environment(ClerkJSCore.Clerk(publishableKey: "pk_test_preview"))
        .clerkAppIcon(Image(systemName: "app.badge"))
        .clerkAppIcon(maxHeight: 20)
        .clerkAppIconView {
          Color.red
            .frame(width: 120, height: 80)
        }
    )

    var renderedSize = CGSize.zero
    renderer.render { size, _ in
      renderedSize = size
    }

    #expect(renderedSize == CGSize(width: 120, height: 80))
  }
}
