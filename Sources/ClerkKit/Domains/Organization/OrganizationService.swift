import Foundation

protocol OrganizationServiceProtocol: Sendable {
  @MainActor func setOrganizationLogo(organizationId: String, imageData: Data) async throws -> Organization
  @MainActor func deleteOrganizationLogo(organizationId: String) async throws -> DeletedObject
}

final class OrganizationService: OrganizationServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func setOrganizationLogo(organizationId: String, imageData: Data) async throws -> Organization {
    let boundary = UUID().uuidString
    var data = Data()
    data.append(Data("\r\n--\(boundary)\r\n".utf8))
    data.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".utf8))
    data.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
    data.append(imageData)
    data.append(Data("\r\n--\(boundary)--\r\n".utf8))

    let request = Request<ClientResponse<Organization>>(
      path: "/v1/organizations/\(organizationId)/logo",
      method: .put,
      headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.upload(for: request, from: data).value.response
  }

  @MainActor
  func deleteOrganizationLogo(organizationId: String) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/organizations/\(organizationId)/logo",
      method: .delete,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }
}
