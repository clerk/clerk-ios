#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct OrganizationListAccountSwitchTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func switchingAccountsReloadsTheListForTheNewUser() async throws {
    let clerk = Clerk.mock
    let view = OrganizationListView(isDismissible: false)
    let accountList = view.accountList
    let host = UIHostingController(rootView: view.environment(clerk))
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = host
    window.isHidden = false
    defer {
      window.isHidden = true
      window.rootViewController = nil
    }
    try await layout(window) { accountList.loadedUserID != nil }
    #expect(accountList.loadedUserID == User.mock.id)

    var client = Client.mock
    client.lastActiveSessionId = Session.mock2.id
    clerk.setClientFromIdentityController(client)
    #expect(clerk.user?.id == User.mock2.id)

    try await layout(window) { accountList.loadedUserID == User.mock2.id }
    #expect(accountList.loadedUserID == User.mock2.id)
  }

  /// Lays the window out until `condition` holds, or for one second when it never does.
  private func layout(_ window: UIWindow, until condition: () -> Bool) async throws {
    for _ in 0 ..< 100 where !condition() {
      window.layoutIfNeeded()
      try await Task.sleep(for: .milliseconds(10))
    }
  }
}

#endif
