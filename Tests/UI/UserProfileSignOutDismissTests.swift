#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct UserProfileSignOutDismissTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func signingOutDismissesAProfileTheHostPresentsInASheet() async throws {
    let clerk = Clerk.mock
    let presentation = PresentationState()
    let host = UIHostingController(rootView: SheetHost(presentation: presentation).environment(clerk))
    let window = show(host)
    defer { hide(window) }
    try await layout(window, host) { presentation.profileAppeared }
    #expect(presentation.profileAppeared)

    clerk.setClientFromIdentityController(.mockSignedOut)

    try await layout(window, host) { !presentation.isPresented }
    #expect(!presentation.isPresented)
  }

  @Test
  func switchingAccountsKeepsTheProfilePresented() async throws {
    let clerk = Clerk.mock
    let presentation = PresentationState()
    let host = UIHostingController(rootView: SheetHost(presentation: presentation).environment(clerk))
    let window = show(host)
    defer { hide(window) }
    try await layout(window, host) { presentation.profileAppeared }
    #expect(presentation.profileAppeared)

    var client = Client.mock
    client.lastActiveSessionId = Session.mock2.id
    clerk.setClientFromIdentityController(client)
    #expect(clerk.user?.id == User.mock2.id)

    try await layout(window, host)
    #expect(presentation.isPresented)
  }

  @Test
  func signingOutRemovesAnEmbeddedProfileFromTheHostPath() async throws {
    let clerk = Clerk.mock
    let pathCount = PathCount()
    let host = UIHostingController(rootView: EmbeddedHost(pathCount: pathCount).environment(clerk))
    let window = show(host)
    defer { hide(window) }
    try await layout(window, host) { pathCount.value == 1 }
    #expect(pathCount.value == 1)

    clerk.setClientFromIdentityController(.mockSignedOut)

    try await layout(window, host) { pathCount.value == 0 }
    #expect(pathCount.value == 0)
  }

  private func show(_ host: UIViewController) -> UIWindow {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = host
    window.isHidden = false
    return window
  }

  private func hide(_ window: UIWindow) {
    window.rootViewController?.presentedViewController?.view.removeFromSuperview()
    window.isHidden = true
    window.rootViewController = nil
  }

  /// Lays the window out until `condition` holds, or for one second when it never does.
  private func layout(
    _ window: UIWindow,
    _ host: UIViewController,
    until condition: () -> Bool = { false }
  ) async throws {
    for _ in 0 ..< 100 where !condition() {
      window.layoutIfNeeded()
      if let presented = host.presentedViewController {
        // The package runner has no window scene to attach presentations automatically.
        if presented.view.superview !== window {
          window.addSubview(presented.view)
          presented.view.frame = window.bounds
        }
        presented.view.layoutIfNeeded()
      }
      try await Task.sleep(for: .milliseconds(10))
    }
  }
}

@MainActor
private final class PresentationState {
  var isPresented = true
  var profileAppeared = false
}

private struct SheetHost: View {
  let presentation: PresentationState

  @State private var profileIsPresented = true

  var body: some View {
    Color.clear
      .sheet(isPresented: $profileIsPresented) {
        UserProfileView()
          .onAppear { presentation.profileAppeared = true }
      }
      .onChange(of: profileIsPresented) { _, isPresented in
        presentation.isPresented = isPresented
      }
  }
}

@MainActor
private final class PathCount {
  var value = -1
}

private struct EmbeddedHost: View {
  enum Route: Hashable {
    case profile
  }

  let pathCount: PathCount

  @State private var path = NavigationPath([Route.profile])

  var body: some View {
    NavigationStack(path: $path) {
      Color.clear
        .navigationDestination(for: Route.self) { _ in
          UserProfileView(isDismissible: false, navigationPath: $path)
        }
    }
    .onAppear { pathCount.value = path.count }
    .onChange(of: path.count) { _, count in pathCount.value = count }
  }
}

#endif
