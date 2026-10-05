#if os(iOS)

@testable import ClerkKit
@_spi(FrameworkIntegration) @testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct AuthViewHostDismissTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func closeButtonRunsTheHostDismissActionWhenTheViewIsNotPresented() async throws {
    var hostDismissCount = 0
    let content = AuthView()
      .environment(Clerk.mockSignedOut)
      .environment(\.clerkHostDismissAction, ClerkHostDismissAction { hostDismissCount += 1 })
      .transaction { $0.disablesAnimations = true }
    let host = UIHostingController(rootView: content)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = host
    window.isHidden = false
    defer {
      window.isHidden = true
      window.rootViewController = nil
    }
    for _ in 0 ..< 6 {
      window.layoutIfNeeded()
      host.view.layoutIfNeeded()
      await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
      }
    }

    let navigation = try #require(navigationController(in: host))
    let item = try #require(navigation.navigationBar.topItem)
    var seen = Set<ObjectIdentifier>()
    let closeItems = ((item.rightBarButtonItems ?? []) + item.trailingItemGroups.flatMap(\.barButtonItems))
      .filter { seen.insert(ObjectIdentifier($0)).inserted }
    let close = try #require(closeItems.first)
    #expect(closeItems.count == 1)
    #expect(hostDismissCount == 0)

    try activate(close)
    #expect(hostDismissCount == 1)
  }

  @Test
  func completedFlowRunsTheHostDismissActionWhenTheViewIsNotPresented() async throws {
    let clerk = Clerk.mockSignedOut
    var authCompleteCount = 0
    var hostDismissCount = 0
    let content = AuthView { authCompleteCount += 1 }
      .environment(clerk)
      .environment(\.clerkHostDismissAction, ClerkHostDismissAction { hostDismissCount += 1 })
      .transaction { $0.disablesAnimations = true }
    let host = UIHostingController(rootView: content)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = host
    window.isHidden = false
    defer {
      window.isHidden = true
      window.rootViewController = nil
    }
    for _ in 0 ..< 6 {
      window.layoutIfNeeded()
      host.view.layoutIfNeeded()
      await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
      }
    }
    let ownerId = try #require(clerk.authFlowRegistrationId)
    clerk.applyRefreshedEnvironment(.mock)

    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = Client.mock.currentSession?.id
    clerk.setClientFromIdentityController(
      .mock,
      authFlowUpdate: .completionAccepted(.signIn(signIn), ownerId: ownerId)
    )

    for _ in 0 ..< 200 where authCompleteCount == 0 {
      window.layoutIfNeeded()
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(authCompleteCount == 1)
    #expect(hostDismissCount == 1)
  }

  private func navigationController(in controller: UIViewController) -> UINavigationController? {
    if let navigation = controller as? UINavigationController { return navigation }
    return controller.children.lazy.compactMap { navigationController(in: $0) }.first
  }

  private func activate(_ item: UIBarButtonItem) throws {
    if let action = item.primaryAction {
      let control = UIControl()
      control.addAction(action, for: .primaryActionTriggered)
      control.sendActions(for: .primaryActionTriggered)
    } else if let action = item.action {
      let target = try #require(item.target as? NSObject)
      try #require(target.responds(to: action))
      _ = target.perform(action, with: item)
    } else {
      let customView = try #require(item.customView)
      let control = try #require(([customView] + descendants(of: customView)).compactMap { $0 as? UIControl }.first)
      control.sendActions(for: .touchUpInside)
    }
  }

  private func descendants(of view: UIView) -> [UIView] {
    view.subviews.flatMap { [$0] + descendants(of: $0) }
  }
}

#endif
