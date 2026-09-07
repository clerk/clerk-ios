@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct UserTests {
  init() {
    configureClerkForTesting()
  }

  private func configureService(_ service: MockUserService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      userService: service
    )
    try! (Clerk.shared.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: .init())
  }

  @Test
  func getOrganizationInvitationsUsesUserServiceGetOrganizationInvitations() async throws {
    let captured = LockIsolated<(Int, Int, [String])?>(nil)
    let service = MockUserService(getOrganizationInvitations: { offset, pageSize, status in
      captured.setValue((offset, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureService(service)

    _ = try await User.mock.getOrganizationInvitations(page: 2, pageSize: 10, status: ["pending", "accepted"])

    let params = try #require(captured.value)
    #expect(params.0 == 10)
    #expect(params.1 == 10)
    #expect(params.2 == ["pending", "accepted"])
  }

  @Test
  func getOrganizationMembershipsUsesUserServiceGetOrganizationMemberships() async throws {
    let captured = LockIsolated<(Int, Int)?>(nil)
    let service = MockUserService(getOrganizationMemberships: { offset, pageSize in
      captured.setValue((offset, pageSize))
      return ClerkPaginatedResponse(data: [.mockWithUserData], totalCount: 1)
    })

    configureService(service)

    _ = try await User.mock.getOrganizationMemberships(page: 3, pageSize: 10)

    let params = try #require(captured.value)
    #expect(params.0 == 20)
    #expect(params.1 == 10)
  }

  @Test
  func leaveOrganizationUsesUserServiceLeaveOrganization() async throws {
    let captured = LockIsolated<String?>(nil)
    let service = MockUserService(leaveOrganization: { organizationId in
      captured.setValue(organizationId)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.leaveOrganization(organizationId: "org_123")

    #expect(captured.value == "org_123")
  }

  struct OrganizationSuggestionsScenario: Codable, Equatable {
    let status: [String]
  }

  @Test(
    arguments: [
      OrganizationSuggestionsScenario(status: []),
      OrganizationSuggestionsScenario(status: ["pending", "accepted"]),
    ]
  )
  func getOrganizationSuggestionsUsesUserServiceGetOrganizationSuggestions(
    scenario: OrganizationSuggestionsScenario
  ) async throws {
    let captured = LockIsolated<(Int, Int, [String])?>(nil)
    let service = MockUserService(getOrganizationSuggestions: { offset, pageSize, status in
      captured.setValue((offset, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })

    configureService(service)

    _ = try await User.mock.getOrganizationSuggestions(
      page: 2,
      pageSize: 10,
      status: scenario.status
    )

    let params = try #require(captured.value)
    #expect(params.0 == 10)
    #expect(params.1 == 10)
    #expect(params.2 == scenario.status)
  }

  @Test
  func getSessionsUsesUserServiceGetSessions() async throws {
    let user = User.mock
    let captured = LockIsolated<User?>(nil)
    let service = MockUserService(getSessions: { user in
      captured.setValue(user)
      return [Session.mock]
    })

    configureService(service)

    _ = try await user.getSessions()

    #expect(captured.value?.id == user.id)
  }

  @Test
  func setProfileImageUsesUserServiceSetProfileImage() async throws {
    let imageData = Data("fake image data".utf8)
    let captured = LockIsolated<Data?>(nil)
    let service = MockUserService(setProfileImage: { data in
      captured.setValue(data)
      return ImageResource(id: "1", name: "profile", publicUrl: "https://example.com/image.jpg")
    })

    configureService(service)

    _ = try await User.mock.setProfileImage(imageData: imageData)

    #expect(captured.value == imageData)
  }

  @Test
  func deleteProfileImageUsesUserServiceDeleteProfileImage() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(deleteProfileImage: {
      called.setValue(true)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.deleteProfileImage()

    #expect(called.value == true)
  }
}
