#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct OrganizationListAccountSwitchTests {
  private let transport = FakeTransport.mockDefaults()

  init() {
    configureClerkForTesting()
    transport.stub(UserAPI.getOrganizationMemberships(offset: 0, pageSize: 0)) { _ in
      ClientResponse(response: ClerkPaginatedResponse(data: [OrganizationMembership.mockWithUserData], totalCount: 1), client: nil)
    }
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: APIClient(baseURL: URL(string: "https://mock.clerk.accounts.dev")!, runtimeScope: Clerk.shared.runtimeScope),
      transport: transport
    )
  }

  @Test
  func switchingAccountsReloadsTheListForTheNewUser() async throws {
    let clerk = Clerk.mock
    let view = OrganizationListView(isDismissible: false)
    let accountLists = view.accountLists
    let window = show(view, with: clerk)
    defer { hide(window) }
    try await layout(window) { accountLists.boundScope != nil }
    #expect(accountLists.boundScope?.user.id == User.mock.id)

    var client = Client.mock
    client.lastActiveSessionId = Session.mock2.id
    clerk.setClientFromIdentityController(client)
    #expect(clerk.user?.id == User.mock2.id)

    try await layout(window) { accountLists.boundScope?.user.id == User.mock2.id }
    #expect(accountLists.boundScope?.user.id == User.mock2.id)
  }

  @Test
  func signingOutReleasesTheList() async throws {
    let clerk = Clerk.mock
    let view = OrganizationListView(isDismissible: false)
    let accountLists = view.accountLists
    let window = show(view, with: clerk)
    defer { hide(window) }
    try await layout(window) { accountLists.boundScope != nil }
    let signedInScope = accountLists.boundScope

    clerk.setClientFromIdentityController(.mockSignedOut)
    try await layout(window) { accountLists.boundScope == nil }

    #expect(accountLists.boundScope == nil)
    #expect(accountLists.content(for: signedInScope) == nil)
  }

  @Test
  func reappearingKeepsTheListWithoutReloading() async throws {
    let clerk = Clerk.mock
    let view = OrganizationListView(isDismissible: false)
    let accountLists = view.accountLists
    let window = show(view, with: clerk)
    defer { hide(window) }
    try await layout(window) { accountLists.content(for: accountLists.boundScope)?.isLoading == false }
    let content = try #require(accountLists.content(for: accountLists.boundScope))
    let requestsBefore = membershipRequests()

    let host = window.rootViewController
    window.rootViewController = UIViewController()
    try await layout(window) { false }
    window.rootViewController = host
    try await layout(window) { false }

    #expect(accountLists.content(for: accountLists.boundScope) === content)
    #expect(!content.isLoading)
    #expect(membershipRequests() == requestsBefore)
  }

  private func membershipRequests() -> Int {
    transport.calls.count { $0.path == "/v1/me/organization_memberships" }
  }

  private func show(_ view: OrganizationListView, with clerk: Clerk) -> UIWindow {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = UIHostingController(rootView: view.environment(clerk))
    window.isHidden = false
    return window
  }

  private func hide(_ window: UIWindow) {
    window.isHidden = true
    window.rootViewController = nil
  }

  private func layout(_ window: UIWindow, until condition: () -> Bool) async throws {
    for _ in 0 ..< 100 where !condition() {
      window.layoutIfNeeded()
      try await Task.sleep(for: .milliseconds(10))
    }
  }
}

#endif
