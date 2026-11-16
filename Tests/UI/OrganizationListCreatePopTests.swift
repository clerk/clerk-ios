#if os(iOS)

@testable import ClerkKitUI
import SwiftUI
import Testing

@MainActor
struct OrganizationListCreatePopTests {
  @Test
  func finishingTheInlineFormKeepsTheHostsEntries() {
    var path = NavigationPath(["host-list"])

    OrganizationListView.popEntriesPushed(from: &path, initialCount: 1)

    #expect(path.count == 1)
  }

  @Test
  func finishingAPushedFormPopsOnlyThatForm() {
    var path = NavigationPath(["host-list"])
    path.append(OrganizationListView.Destination.createOrganization)

    OrganizationListView.popEntriesPushed(from: &path, initialCount: 1)

    #expect(path.count == 1)
  }
}

#endif
