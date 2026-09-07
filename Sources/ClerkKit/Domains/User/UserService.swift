import Foundation

protocol UserServiceProtocol: Sendable {
  @MainActor func setProfileImage(imageData: Data) async throws -> ImageResource
  @MainActor func deleteProfileImage() async throws -> DeletedObject
}

final class UserService: UserServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func setProfileImage(imageData: Data) async throws -> ImageResource {
    let boundary = UUID().uuidString
    var data = Data()
    data.append(Data("\r\n--\(boundary)\r\n".utf8))
    data.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".utf8))
    data.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
    data.append(imageData)
    data.append(Data("\r\n--\(boundary)--\r\n".utf8))

    let request = Request<ClientResponse<ImageResource>>(
      path: "/v1/me/profile_image",
      method: .post,
      headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.upload(for: request, from: data).value.response
  }

  @MainActor
  func deleteProfileImage() async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/profile_image",
      method: .delete,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }
}
