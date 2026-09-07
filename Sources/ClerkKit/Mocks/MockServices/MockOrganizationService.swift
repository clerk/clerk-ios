import Foundation

package final class MockOrganizationService: OrganizationServiceProtocol {
  package nonisolated(unsafe) var setOrganizationLogoHandler: ((String, Data) async throws -> Organization)?
  package nonisolated(unsafe) var deleteOrganizationLogoHandler: ((String) async throws -> DeletedObject)?

  package init(
    setOrganizationLogo: ((String, Data) async throws -> Organization)? = nil,
    deleteOrganizationLogo: ((String) async throws -> DeletedObject)? = nil
  ) {
    setOrganizationLogoHandler = setOrganizationLogo
    deleteOrganizationLogoHandler = deleteOrganizationLogo
  }

  @MainActor
  package func setOrganizationLogo(organizationId: String, imageData: Data) async throws -> Organization {
    if let handler = setOrganizationLogoHandler {
      return try await handler(organizationId, imageData)
    }
    return .mock
  }

  @MainActor
  package func deleteOrganizationLogo(organizationId: String) async throws -> DeletedObject {
    if let handler = deleteOrganizationLogoHandler {
      return try await handler(organizationId)
    }
    return .mock
  }
}
