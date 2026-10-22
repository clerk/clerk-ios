@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
struct OrganizationScopedStoreTests {
  private let made = ContentLog()

  @Test
  func bindingTheSameScopeKeepsItsContent() throws {
    let store = makeStore()
    store.bind(scope(org: "org_a"))
    let content = try #require(store.content(for: scope(org: "org_a")))

    store.bind(scope(org: "org_a"))

    #expect(store.content(for: scope(org: "org_a")) === content)
    #expect(made.contents.count == 1)
    #expect(content.starts == 1)
    #expect(!content.isRetired)
  }

  @Test
  func bindingANewScopeRetiresTheOldContent() throws {
    let store = makeStore()
    store.bind(scope(org: "org_a"))
    let old = try #require(store.content(for: scope(org: "org_a")))

    store.bind(scope(org: "org_b"))

    #expect(old.isRetired)
    #expect(store.content(for: scope(org: "org_b"))?.scope.organization.id == "org_b")
    #expect(store.content(for: scope(org: "org_b"))?.starts == 1)
  }

  @Test
  func bindingNilHoldsNothing() throws {
    let store = makeStore()
    store.bind(scope(org: "org_a"))
    let old = try #require(store.content(for: scope(org: "org_a")))

    store.bind(nil)

    #expect(old.isRetired)
    #expect(store.boundScope == nil)
    #expect(store.content(for: scope(org: "org_a")) == nil)
  }

  @Test
  func contentForAnotherScopeIsNil() {
    let store = makeStore()
    store.bind(scope(org: "org_a"))

    #expect(store.content(for: scope(org: "org_b")) == nil)
    #expect(store.content(for: scope(org: "org_a", user: "user_b")) == nil)
    #expect(store.content(for: nil) == nil)
  }

  @Test
  func organizationMetadataIsNotPartOfTheScope() {
    var renamed = Organization.mock
    renamed.name = "Renamed"
    renamed.membersCount = 42

    #expect(scope(org: Organization.mock.id) == OrganizationScope(userID: "user_a", organization: renamed, access: [.readMemberships]))
  }

  @Test
  func accessIsPartOfTheScope() {
    let store = makeStore()
    store.bind(scope(org: "org_a"))

    store.bind(scope(org: "org_a", access: [.readMemberships, .manageMemberships]))

    #expect(made.contents.count == 2)
    #expect(made.contents[0].isRetired)
  }

  private func makeStore() -> OrganizationScopedStore<FakeContent> {
    OrganizationScopedStore { [made] scope in
      let content = FakeContent(scope: scope)
      made.contents.append(content)
      return content
    }
  }

  private func scope(org: String, user: String = "user_a", access: OrganizationAccess = [.readMemberships]) -> OrganizationScope {
    var organization = Organization.mock
    organization.id = org
    return OrganizationScope(userID: user, organization: organization, access: access)
  }
}

@MainActor
@Observable
private final class FakeContent: OrganizationScopedContent {
  let scope: OrganizationScope
  var starts = 0
  var isRetired = false

  init(scope: OrganizationScope) {
    self.scope = scope
  }

  func start() {
    starts += 1
  }

  func retire() {
    isRetired = true
  }
}

@MainActor
private final class ContentLog {
  var contents: [FakeContent] = []
}
