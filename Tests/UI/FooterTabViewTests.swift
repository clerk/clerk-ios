#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct FooterTabViewTests {
  @Test(arguments: [true, false])
  func developmentLabelStaysAboveTheTabBar(isAuth: Bool) async throws {
    let clerk = Clerk.mockSignedOut
    clerk.environment?.displayConfig.showDevmodeWarning = true
    let bottomInset: CGFloat = 34
    let content = TabView {
      Group {
        if isAuth {
          Color.white.authFooter()
        } else {
          Color.white.securedByClerkFooter()
        }
      }
        .environment(clerk)
        .tabItem { Label("Home", systemImage: "house.fill") }
      Text("My View")
        .tabItem { Label("Settings", systemImage: "gear") }
    }
    .environment(\.colorScheme, .light)
    .environment(\.dynamicTypeSize, .large)
    .environment(\.locale, Locale(identifier: "en_US"))
    .environment(\.clerkFooterHostBottomInset, bottomInset)
    let host = UIHostingController(rootView: content)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 220))
    window.rootViewController = host
    window.overrideUserInterfaceStyle = .light
    window.isHidden = false
    defer {
      window.isHidden = true
      window.rootViewController = nil
    }
    for _ in 0 ..< 5 {
      window.layoutIfNeeded()
      host.view.layoutIfNeeded()
      await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
      }
    }
    let tabBar = try #require(descendants(of: window).compactMap { $0 as? UITabBar }.first)
    #expect(tabBar.bounds.height > bottomInset)
    // Layer snapshots cannot render the glass material; mark the real tab bar's bounds instead.
    tabBar.backgroundColor = .lightGray
    assertSnapshot(
      of: host,
      as: .image(
        on: ViewImageConfig(
          safeArea: UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0),
          size: window.bounds.size
        ),
        precision: 0.99,
        perceptualPrecision: 0.98,
        traits: UITraitCollection(displayScale: 3)
      ),
      named: isAuth ? "auth" : "profile"
    )
  }

  private func descendants(of view: UIView) -> [UIView] {
    [view] + view.subviews.flatMap { descendants(of: $0) }
  }
}

#endif
