@testable import ClerkKit
import Testing

@MainActor
@Suite(.serialized)
struct OrganizationsTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func createUsesEngineCreateOrganization() async throws {
    let engine = RecordingEngineClient()
    Clerk.engineClient = engine

    let organization = try await Clerk.shared.organizations.create(name: "My Org", slug: nil)

    #expect(engine.createdOrganizationName == "My Org")
    #expect(engine.createdOrganizationSlug == nil)
    #expect(organization.id == Organization.mock.id)
  }

  @Test
  func getUsesEngineGetOrganization() async throws {
    let engine = RecordingEngineClient()
    Clerk.engineClient = engine

    let organization = try await Clerk.shared.organizations.get(id: "org_123")

    #expect(engine.fetchedOrganizationId == "org_123")
    #expect(organization.id == Organization.mock.id)
  }
}
