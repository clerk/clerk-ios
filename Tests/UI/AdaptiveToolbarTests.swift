#if os(iOS)

@_spi(FrameworkIntegration) @testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
struct AdaptiveToolbarTests {
  @Test
  func embeddedBackAndCloseRemainAvailableTogether() async throws {
    let fixture = AdaptiveToolbarFixture(hasHostBackAction: true)
    defer { fixture.close() }
    await fixture.layout()

    let back = try fixture.buttonItem(on: .leading)
    let close = try fixture.buttonItem(on: .trailing)
    #expect(back !== close)
    #expect(back.isEnabled)
    #expect(close.isEnabled)

    try fixture.activate(back)
    #expect(fixture.state.hostBackCount == 1)
    #expect(fixture.state.closeCount == 0)

    try fixture.activate(close)
    #expect(fixture.state.hostBackCount == 1)
    #expect(fixture.state.closeCount == 1)
  }

  @Test
  func pushedScreenKeepsNativeBackAlongsideClose() async throws {
    let fixture = AdaptiveToolbarFixture(hasHostBackAction: false)
    defer { fixture.close() }
    await fixture.layout()
    fixture.state.path.append(1)
    await fixture.layout()

    let navigation = try #require(fixture.navigationController)
    #expect(navigation.viewControllers.count == 2)
    let item = try #require(navigation.navigationBar.topItem)
    #expect(!item.hidesBackButton)
    #expect(item.leftBarButtonItems?.isEmpty != false || item.leftItemsSupplementBackButton)
    #expect(navigation.navigationBar.backItem != nil)
    #expect(navigation.navigationBar.isUserInteractionEnabled)

    let close = try fixture.buttonItem(on: .trailing)
    #expect(close.isEnabled)
    try fixture.activate(close)
    #expect(fixture.state.closeCount == 1)

    // UIKit owns the native Back control. Verify its navigation transition preserves
    // the SwiftUI path without depending on private toolbar view subclasses.
    #expect(navigation.popViewController(animated: false) != nil)
    await fixture.layout()
    #expect(fixture.state.path.isEmpty)
    #expect(navigation.viewControllers.count == 1)
  }
}

@MainActor
private final class AdaptiveToolbarFixture {
  let state = AdaptiveToolbarState()
  let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
  let host: UIHostingController<AdaptiveToolbarProbe>

  init(hasHostBackAction: Bool) {
    host = UIHostingController(rootView: AdaptiveToolbarProbe(state: state, hasHostBackAction: hasHostBackAction))
    window.rootViewController = host
    window.isHidden = false
  }

  var navigationController: UINavigationController? {
    func find(in controller: UIViewController) -> UINavigationController? {
      if let navigation = controller as? UINavigationController { return navigation }
      return controller.children.lazy.compactMap { find(in: $0) }.first
    }
    return find(in: host)
  }

  enum ToolbarSide {
    case leading
    case trailing
  }

  func buttonItem(on side: ToolbarSide) throws -> UIBarButtonItem {
    let navigation = try #require(navigationController)
    let item = try #require(navigation.navigationBar.topItem)
    let candidates: [UIBarButtonItem] = switch side {
    case .leading:
      (item.leftBarButtonItems ?? []) + item.leadingItemGroups.flatMap(\.barButtonItems)
    case .trailing:
      (item.rightBarButtonItems ?? []) + item.trailingItemGroups.flatMap(\.barButtonItems)
    }

    // SwiftUI's hosted toolbar views do not expose their accessibility labels through
    // UIKit on every supported OS. Locate the controls by their toolbar positions;
    // the tests verify their identities by dispatching their actual configured actions.
    // UIKit can list the same item both individually and in a group.
    var seen = Set<ObjectIdentifier>()
    let items = candidates.filter { seen.insert(ObjectIdentifier($0)).inserted }
    try #require(items.count == 1, "Expected one \(side) toolbar button, found \(items.count)")
    return try #require(items.first)
  }

  func activate(_ item: UIBarButtonItem) throws {
    if let action = item.primaryAction {
      // Dispatch the exact action configured by SwiftUI using UIControl's public action API.
      let control = UIControl()
      control.addAction(action, for: .primaryActionTriggered)
      control.sendActions(for: .primaryActionTriggered)
    } else if let action = item.action {
      // The package test runner has no application action dispatcher.
      let target = try #require(item.target as? NSObject)
      try #require(target.responds(to: action))
      _ = target.perform(action, with: item)
    } else {
      let customView = try #require(item.customView)
      let control = try #require(([customView] + descendants(of: customView)).compactMap { $0 as? UIControl }.first)
      #expect(control.isEnabled)
      control.sendActions(for: .touchUpInside)
    }
  }

  func layout() async {
    for _ in 0 ..< 6 {
      window.setNeedsLayout()
      window.layoutIfNeeded()
      host.view.layoutIfNeeded()
      navigationController?.view.layoutIfNeeded()
      await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
      }
    }
  }

  func close() {
    window.isHidden = true
    window.rootViewController = nil
  }

  private func descendants(of view: UIView) -> [UIView] {
    view.subviews.flatMap { [$0] + descendants(of: $0) }
  }
}

@MainActor
@Observable
private final class AdaptiveToolbarState {
  var path: [Int] = []
  var hostBackCount = 0
  var closeCount = 0
}

private struct AdaptiveToolbarProbe: View {
  @Bindable var state: AdaptiveToolbarState
  let hasHostBackAction: Bool

  var body: some View {
    NavigationStack(path: $state.path) {
      Text("Root content")
        .navigationTitle("Root")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          DismissToolbarItem { state.closeCount += 1 }
        }
        .hostBackToolbar()
        .navigationDestination(for: Int.self) { _ in
          Text("Destination content")
            .navigationTitle("Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
              DismissToolbarItem { state.closeCount += 1 }
            }
        }
    }
    .environment(\.clerkHostBackAction, hasHostBackAction ? ClerkHostBackAction { state.hostBackCount += 1 } : nil)
    .transaction { $0.disablesAnimations = true }
  }
}

#endif
