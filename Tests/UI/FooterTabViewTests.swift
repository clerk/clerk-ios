#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct FooterTabViewTests {
  @Test(arguments: [true, false])
  func developmentLabelStaysAboveTheTabBar(isAuth: Bool) async throws {
    configureClerkForTesting()
    Clerk.shared.dependencies = MockDependencyContainer(apiClient: Clerk.shared.dependencies.apiClient)
    let clerk = isAuth ? Clerk.mockSignedOut : Clerk.mock
    clerk.environment?.displayConfig.showDevmodeWarning = true
    let content = TabView {
      Group {
        if isAuth {
          AuthView(isDismissible: false)
        } else {
          UserProfileView(isDismissible: false)
        }
      }
        .environment(clerk)
        .tabItem { Label("Home", systemImage: "house.fill") }
      Text("My View")
        .tabItem { Label("Settings", systemImage: "gear") }
    }
    let host = UIHostingController(rootView: content)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = host
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
    let tabFrame = tabBar.convert(tabBar.bounds, to: window)
    let elements = accessibilityDescendants(of: host.view)
    let label = try #require(elements.first { $0.accessibilityLabel == "Development mode" })
    #expect(label.accessibilityFrame.height > 0)
    #expect(label.accessibilityFrame.maxY <= tabFrame.minY)
  }

  private func descendants(of view: UIView) -> [UIView] {
    [view] + view.subviews.flatMap { descendants(of: $0) }
  }

  private func accessibilityDescendants(of object: NSObject) -> [NSObject] {
    let children: [NSObject] = if let elements = object.accessibilityElements as? [NSObject], !elements.isEmpty {
      elements
    } else if object.accessibilityElementCount() > 0, object.accessibilityElementCount() != NSNotFound {
      (0 ..< object.accessibilityElementCount()).compactMap { object.accessibilityElement(at: $0) as? NSObject }
    } else {
      (object as? UIView)?.subviews ?? []
    }
    return [object] + children.flatMap { accessibilityDescendants(of: $0) }
  }
}

#endif
