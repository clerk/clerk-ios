import Foundation

protocol OrganizationServiceProtocol: Sendable {
  @MainActor func setOrganizationLogo(organizationId: String, imageData: Data) async throws -> Organization
  @MainActor func deleteOrganizationLogo(organizationId: String) async throws -> DeletedObject
}

final class OrganizationService: OrganizationServiceProtocol {
  init() {}

  @MainActor
  func setOrganizationLogo(organizationId: String, imageData: Data) async throws -> Organization {
    try await Clerk.js(.clerk, JSRawCall("setNativeOrganizationLogo", .string(organizationId), .string(imageData.base64EncodedString())), as: Organization.self)
  }

  @MainActor
  func deleteOrganizationLogo(organizationId: String) async throws -> DeletedObject {
    try await Clerk.js(.clerk, JSRawCall("deleteNativeOrganizationLogo", .string(organizationId)), as: DeletedObject.self)
  }
}
