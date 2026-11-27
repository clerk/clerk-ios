#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct UserProfileSplitLayoutTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func wideRegularProfileShowsTheListBesideThePage() async throws {
    let fixture = UserProfileSplitLayoutFixture(width: 1024, sizeClass: .regular) {
      UserProfileView(isDismissible: false)
    }
    defer { fixture.close() }

    try await fixture.layout { fixture.splitViewController?.minimumPrimaryColumnWidth == 260 }
    #expect(fixture.splitViewController?.minimumPrimaryColumnWidth == 260)
    #expect(fixture.splitViewController?.maximumPrimaryColumnWidth == 400)
  }

  @Test
  func compactProfileKeepsASingleStack() async throws {
    let fixture = UserProfileSplitLayoutFixture(width: 1024, sizeClass: .compact) {
      UserProfileView(isDismissible: false)
    }
    defer { fixture.close() }

    try await fixture.layout()
    #expect(fixture.splitViewController == nil)
  }

  @Test
  func regularProfileNarrowerThanTheMinimumKeepsASingleStack() async throws {
    let fixture = UserProfileSplitLayoutFixture(width: 600, sizeClass: .regular) {
      UserProfileView(isDismissible: false)
    }
    defer { fixture.close() }

    try await fixture.layout()
    #expect(fixture.splitViewController == nil)
  }

  @Test
  func stackLayoutKeepsASingleStackWhenWide() async throws {
    let fixture = UserProfileSplitLayoutFixture(width: 1024, sizeClass: .regular) {
      UserProfileView(isDismissible: false)
        .userProfileLayout(.stack)
    }
    defer { fixture.close() }

    try await fixture.layout()
    #expect(fixture.splitViewController == nil)
  }

  @Test
  func profileEmbeddedInTheHostPathKeepsASingleStack() async throws {
    let fixture = UserProfileSplitLayoutFixture(width: 1024, sizeClass: .regular) {
      EmbeddedHost()
    }
    defer { fixture.close() }

    try await fixture.layout()
    #expect(fixture.splitViewController == nil)
  }
}

@MainActor
private final class UserProfileSplitLayoutFixture {
  let window: UIWindow
  let host: UIViewController

  init(width: CGFloat, sizeClass: UIUserInterfaceSizeClass, @ViewBuilder content: () -> some View) {
    host = UIHostingController(rootView: content().environment(Clerk.mock))
    host.traitOverrides.horizontalSizeClass = sizeClass
    window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 800))
    window.rootViewController = host
    window.isHidden = false
  }

  var splitViewController: UISplitViewController? {
    Self.splitViewControllers(in: host).first
  }

  /// Lays the window out until `condition` holds, or for one second when it never does.
  func layout(until condition: () -> Bool = { false }) async throws {
    for _ in 0 ..< 100 where !condition() {
      window.layoutIfNeeded()
      try await Task.sleep(for: .milliseconds(10))
    }
  }

  func close() {
    window.isHidden = true
    window.rootViewController = nil
  }

  private static func splitViewControllers(in controller: UIViewController) -> [UISplitViewController] {
    let own = (controller as? UISplitViewController).map { [$0] } ?? []
    return own + controller.children.flatMap { splitViewControllers(in: $0) }
  }
}

private struct EmbeddedHost: View {
  @State private var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      UserProfileView(isDismissible: false, navigationPath: $path)
    }
  }
}

#endif
